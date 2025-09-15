require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const multer = require('multer');
let admin = null;
try {
  admin = require('firebase-admin');
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    if (!admin.apps.length) {
      if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
        const svc = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
        admin.initializeApp({ credential: admin.credential.cert(svc) });
      } else {
        admin.initializeApp({});
      }
    }
  }
} catch (_) {}

// ----- Config -----
const app = express();
const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
  console.error('Missing MONGODB_URI in .env');
  process.exit(1);
}

app.use(cors({ origin: '*', methods: ['GET', 'POST', 'OPTIONS'], allowedHeaders: ['Content-Type', 'x-user-id'] }));
app.use(helmet());
app.use(express.json({ limit: '16kb' }));
app.use(morgan('dev'));

// ----- DB & Models -----
mongoose
  .connect(MONGODB_URI, {
    autoIndex: true,
  })
  .then(() => console.log('MongoDB connected'))
  .catch((err) => {
    console.error('MongoDB connection error:', err.message);
    process.exit(1);
  });

const entrySchema = new mongoose.Schema(
  {
    content: { type: String, required: true, trim: true, maxlength: 2000 },
    hearts: { type: Number, default: 0 },
    repliesCount: { type: Number, default: 0 },
    authorId: { type: String, default: null, index: true },
    emotion: { type: String, default: null },
    imageUrl: { type: String, default: null },
    reactionsCounts: {
      heart: { type: Number, default: 0 },
      happy: { type: Number, default: 0 },
      sad: { type: Number, default: 0 },
      angry: { type: Number, default: 0 },
    },
  },
  { timestamps: true }
);

const replySchema = new mongoose.Schema(
  {
    entryId: { type: mongoose.Schema.Types.ObjectId, ref: 'Entry', required: true, index: true },
    content: { type: String, required: true, trim: true, maxlength: 1000 },
    authorId: { type: String, default: null, index: true },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

const Entry = mongoose.model('Entry', entrySchema);
const Reply = mongoose.model('Reply', replySchema);
const userSchema = new mongoose.Schema(
  {
    email: { type: String, unique: true, sparse: true, index: true },
    passwordHash: { type: String },
    provider: { type: String, enum: ['anonymous', 'email'], default: 'anonymous' },
    anonId: { type: String, unique: true, index: true },
  },
  { timestamps: true }
);
const User = mongoose.model('User', userSchema);

const reactionSchema = new mongoose.Schema(
  {
    entryId: { type: mongoose.Schema.Types.ObjectId, ref: 'Entry', index: true, required: true },
    userId: { type: String, index: true, required: true },
    type: { type: String, enum: ['heart', 'happy', 'sad', 'angry'], required: true },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);
reactionSchema.index({ entryId: 1, userId: 1 }, { unique: true });
const Reaction = mongoose.model('Reaction', reactionSchema);
const ALLOWED_REACTIONS = ['heart', 'happy', 'sad', 'angry'];

// Social: follow, friendship, messages
const followSchema = new mongoose.Schema(
  {
    followerId: { type: String, required: true, index: true },
    followingId: { type: String, required: true, index: true },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);
followSchema.index({ followerId: 1, followingId: 1 }, { unique: true });
const Follow = mongoose.model('Follow', followSchema);

const friendRequestSchema = new mongoose.Schema(
  {
    fromId: { type: String, required: true, index: true },
    toId: { type: String, required: true, index: true },
    status: { type: String, enum: ['pending', 'accepted', 'rejected'], default: 'pending' },
  },
  { timestamps: true }
);
friendRequestSchema.index({ fromId: 1, toId: 1 }, { unique: true });
const FriendRequest = mongoose.model('FriendRequest', friendRequestSchema);

const messageSchema = new mongoose.Schema(
  {
    conversationKey: { type: String, index: true }, // sorted pair: userA|userB
    fromId: { type: String, required: true, index: true },
    toId: { type: String, required: true, index: true },
    content: { type: String, required: true, maxlength: 2000 },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);
const Message = mongoose.model('Message', messageSchema);

// ----- Validation helpers (Node 12 friendly) -----
function validateEntryBody(body) {
  if (!body || typeof body.content !== 'string') return 'INVALID_BODY';
  var content = body.content.trim();
  if (content.length === 0) return 'EMPTY_CONTENT';
  if (content.length > 2000) return 'CONTENT_TOO_LONG';
  return null;
}

function validateReplyBody(body) {
  if (!body || typeof body.content !== 'string') return 'INVALID_BODY';
  var content = body.content.trim();
  if (content.length === 0) return 'EMPTY_CONTENT';
  if (content.length > 1000) return 'CONTENT_TOO_LONG';
  return null;
}

// ----- Routes -----
// Anonymous auth issue userId
app.post('/api/auth/anonymous', (req, res) => {
  try {
    var id = 'user_' + Math.random().toString(36).slice(2, 10);
    return res.status(201).json({ userId: id });
  } catch (err) {
    return res.status(500).json({ error: 'INTERNAL_ERROR' });
  }
});

// Simplified email register/login (no JWT; returns userId)
function normalizeEmail(s) {
  return (s || '').toString().trim().toLowerCase();
}

const crypto = require('crypto');
function hashPassword(pw) {
  return crypto.createHash('sha256').update(pw).digest('hex');
}

app.post('/api/auth/register', async (req, res) => {
  try {
    const email = normalizeEmail(req.body && req.body.email);
    const password = (req.body && req.body.password) ? String(req.body.password) : '';
    if (!email || !password || password.length < 6) return res.status(400).json({ error: 'INVALID_CREDENTIALS' });
    const exists = await User.findOne({ email }).lean();
    if (exists) return res.status(409).json({ error: 'EMAIL_EXISTS' });
    const anonId = 'user_' + Math.random().toString(36).slice(2, 10);
    const created = await User.create({ email, passwordHash: hashPassword(password), provider: 'email', anonId });
    return res.status(201).json({ userId: created.anonId });
  } catch (err) {
    console.error('POST /api/auth/register error:', err);
    return res.status(500).json({ error: 'INTERNAL_ERROR' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const email = normalizeEmail(req.body && req.body.email);
    const password = (req.body && req.body.password) ? String(req.body.password) : '';
    if (!email || !password) return res.status(400).json({ error: 'INVALID_CREDENTIALS' });
    const u = await User.findOne({ email }).lean();
    if (!u) return res.status(404).json({ error: 'NOT_FOUND' });
    if (u.passwordHash !== hashPassword(password)) return res.status(401).json({ error: 'WRONG_PASSWORD' });
    return res.json({ userId: u.anonId });
  } catch (err) {
    console.error('POST /api/auth/login error:', err);
    return res.status(500).json({ error: 'INTERNAL_ERROR' });
  }
});
app.get('/healthz', (req, res) => {
  return res.json({ ok: true, timestamp: Date.now() });
});

// Simple local storage for images (dev only)
const upload = multer({ dest: 'uploads/' });

// Create entry (anonymous). Supports JSON or multipart (image)
app.post('/api/entries', upload.single('image'), async (req, res) => {
  try {
    var userIdHeader = req.header('x-user-id');
    var authorId = typeof userIdHeader === 'string' ? userIdHeader.trim() : null;
    var body = req.body || {};
    var errCode = validateEntryBody(body);
    if (errCode) return res.status(400).json({ error: errCode });
    const content = body.content.trim();
    const emotion = (body.emotion || '').toString().trim() || null;
    let imageUrl = null;
    if (req.file) {
      imageUrl = `/uploads/${req.file.filename}`;
    } else if (body.imageUrl) {
      imageUrl = body.imageUrl;
    }
    const entry = await Entry.create({ content: content, authorId: authorId || null, emotion: emotion, imageUrl: imageUrl });
    return res.status(201).json({ id: entry._id, content: entry.content, hearts: entry.hearts, repliesCount: entry.repliesCount, createdAt: entry.createdAt, authorId: entry.authorId, emotion: entry.emotion, imageUrl: entry.imageUrl });
  } catch (err) {
    console.error('POST /api/entries error:', err);
    return res.status(500).json({ error: 'INTERNAL_ERROR' });
  }
});

// Feed entries
// mode=random|latest; page & limit for latest; limit only for random
app.get('/api/entries', async (req, res) => {
  try {
    const mode = (req.query.mode || 'random').toString();
    const page = Math.max(1, parseInt(req.query.page || '1', 10));
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit || '20', 10)));

    if (mode === 'latest') {
      const items = await Entry.find()
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .lean();
      return res.json({ mode, page, limit, items });
    }

    if (mode === 'recommended') {
      const items = await Entry.aggregate([
        { $addFields: {
            totalReactions: {
              $add: [
                { $ifNull: [ '$hearts', 0 ] },
                { $ifNull: [ '$repliesCount', 0 ] },
                { $ifNull: [ '$reactionsCounts.heart', 0 ] },
                { $ifNull: [ '$reactionsCounts.happy', 0 ] },
                { $ifNull: [ '$reactionsCounts.sad', 0 ] },
                { $ifNull: [ '$reactionsCounts.angry', 0 ] },
              ]
            }
        } },
        { $sort: { totalReactions: -1, createdAt: -1 } },
        { $skip: (page - 1) * limit },
        { $limit: limit },
        { $project: { content: 1, hearts: 1, repliesCount: 1, createdAt: 1, emotion: 1, imageUrl: 1, reactionsCounts: 1 } },
      ]);
      return res.json({ mode, page, limit, items });
    }

    // Random feed
    const sampled = await Entry.aggregate([
      { $sample: { size: limit } },
      { $project: { content: 1, hearts: 1, repliesCount: 1, createdAt: 1, emotion: 1, imageUrl: 1, reactionsCounts: 1, authorId: 1 } },
    ]);
    return res.json({ mode: 'random', limit, items: sampled });
  } catch (err) {
    console.error('GET /api/entries error:', err);
    return res.status(500).json({ error: 'INTERNAL_ERROR' });
  }
});

// Heart an entry
app.post('/api/entries/:id/heart', async (req, res) => {
  try {
    // Backwards compatibility: map to unified reaction 'heart'
    const { id } = req.params;
    if (!mongoose.isValidObjectId(id)) return res.status(400).json({ error: 'INVALID_ID' });
    req.body = { type: 'heart' };
    return reactHandler(req, res);
  } catch (err) {
    console.error('POST /api/entries/:id/heart error:', err);
    return res.status(500).json({ error: 'INTERNAL_ERROR' });
  }
});

// React to an entry (one reaction per user per entry)
async function reactHandler(req, res) {
  try {
    const { id } = req.params;
    if (!mongoose.isValidObjectId(id)) return res.status(400).json({ error: 'INVALID_ID' });
    const userId = (req.header('x-user-id') || '').toString().trim();
    if (!userId) return res.status(401).json({ error: 'NO_USER' });
    const type = (req.body && req.body.type ? String(req.body.type) : '').trim();
    if (!ALLOWED_REACTIONS.includes(type)) return res.status(400).json({ error: 'INVALID_REACTION' });

    const entry = await Entry.findById(id);
    if (!entry) return res.status(404).json({ error: 'NOT_FOUND' });

    let current = await Reaction.findOne({ entryId: id, userId }).lean();
    if (!current) {
      await Reaction.create({ entryId: id, userId, type });
      entry.reactionsCounts[type] = (entry.reactionsCounts[type] || 0) + 1;
      await entry.save();
      return res.json({ ok: true, counts: entry.reactionsCounts, myReaction: type });
    }
    if (current.type === type) {
      // idempotent: keep same reaction (do not toggle-off)
      return res.json({ ok: true, counts: entry.reactionsCounts, myReaction: type });
    }
    // switch reaction
    await Reaction.updateOne({ entryId: id, userId }, { $set: { type } });
    if (entry.reactionsCounts[current.type] > 0) entry.reactionsCounts[current.type] -= 1;
    entry.reactionsCounts[type] = (entry.reactionsCounts[type] || 0) + 1;
    await entry.save();
    return res.json({ ok: true, counts: entry.reactionsCounts, myReaction: type });
  } catch (err) {
    console.error('reactHandler error:', err);
    return res.status(500).json({ error: 'INTERNAL_ERROR' });
  }
}

app.post('/api/entries/:id/react', reactHandler);

// ---- Follow APIs ----
app.post('/api/social/follow/:targetId', async (req, res) => {
  try {
    const me = (req.header('x-user-id') || '').toString().trim();
    const target = req.params.targetId;
    if (!me || !target || me === target) return res.status(400).json({ error: 'INVALID' });
    await Follow.updateOne({ followerId: me, followingId: target }, { $setOnInsert: { followerId: me, followingId: target } }, { upsert: true });
    return res.json({ ok: true });
  } catch (err) {
    console.error('POST /follow error', err); return res.status(500).json({ error: 'INTERNAL_ERROR' });
  }
});

app.delete('/api/social/follow/:targetId', async (req, res) => {
  try {
    const me = (req.header('x-user-id') || '').toString().trim();
    const target = req.params.targetId;
    await Follow.deleteOne({ followerId: me, followingId: target });
    return res.json({ ok: true });
  } catch (err) { console.error('DELETE /follow error', err); return res.status(500).json({ error: 'INTERNAL_ERROR' }); }
});

// ---- Friend request APIs ----
app.post('/api/social/friends/request/:toId', async (req, res) => {
  try {
    const fromId = (req.header('x-user-id') || '').toString().trim();
    const toId = req.params.toId;
    if (!fromId || !toId || fromId === toId) return res.status(400).json({ error: 'INVALID' });
    const fr = await FriendRequest.findOneAndUpdate({ fromId, toId }, { $setOnInsert: { fromId, toId, status: 'pending' } }, { upsert: true, new: true });
    return res.json({ ok: true, requestId: fr._id, status: fr.status });
  } catch (err) { console.error('POST /friends/request error', err); return res.status(500).json({ error: 'INTERNAL_ERROR' }); }
});

app.post('/api/social/friends/respond/:requestId', async (req, res) => {
  try {
    const me = (req.header('x-user-id') || '').toString().trim();
    const { requestId } = req.params;
    const { action } = req.body || {};
    const fr = await FriendRequest.findById(requestId);
    if (!fr) return res.status(404).json({ error: 'NOT_FOUND' });
    if (fr.toId !== me) return res.status(403).json({ error: 'FORBIDDEN' });
    if (action === 'accept') {
      fr.status = 'accepted';
      await fr.save();
    } else if (action === 'reject') {
      fr.status = 'rejected';
      await fr.save();
    } else {
      return res.status(400).json({ error: 'INVALID_ACTION' });
    }
    return res.json({ ok: true, status: fr.status });
  } catch (err) { console.error('POST /friends/respond error', err); return res.status(500).json({ error: 'INTERNAL_ERROR' }); }
});

// ---- Messaging APIs ----
function conversationKey(a, b) {
  return [a, b].sort().join('|');
}

app.post('/api/messages/:toId', async (req, res) => {
  try {
    const fromId = (req.header('x-user-id') || '').toString().trim();
    const toId = req.params.toId;
    const content = (req.body && req.body.content ? String(req.body.content) : '').trim();
    if (!fromId || !toId || !content) return res.status(400).json({ error: 'INVALID' });
    const key = conversationKey(fromId, toId);
    const msg = await Message.create({ conversationKey: key, fromId, toId, content });
    return res.status(201).json({ id: msg._id, fromId, toId, content, createdAt: msg.createdAt });
  } catch (err) { console.error('POST /messages error', err); return res.status(500).json({ error: 'INTERNAL_ERROR' }); }
});

app.get('/api/messages/:peerId', async (req, res) => {
  try {
    const me = (req.header('x-user-id') || '').toString().trim();
    const peer = req.params.peerId;
    const page = Math.max(1, parseInt(req.query.page || '1', 10));
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit || '30', 10)));
    const key = conversationKey(me, peer);
    const items = await Message.find({ conversationKey: key }).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit).lean();
    return res.json({ page, limit, items: items.reverse() });
  } catch (err) { console.error('GET /messages error', err); return res.status(500).json({ error: 'INTERNAL_ERROR' }); }
});

// Create a reply (anonymous)
app.post('/api/entries/:id/replies', async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.isValidObjectId(id)) return res.status(400).json({ error: 'INVALID_ID' });
    var userIdHeader = req.header('x-user-id');
    var authorId = typeof userIdHeader === 'string' ? userIdHeader.trim() : null;
    var errCode = validateReplyBody(req.body);
    if (errCode) return res.status(400).json({ error: errCode });
    const content = req.body.content.trim();
    const entry = await Entry.findById(id).select('_id');
    if (!entry) return res.status(404).json({ error: 'NOT_FOUND' });

    const reply = await Reply.create({ entryId: entry._id, content, authorId: authorId || null });
    await Entry.updateOne({ _id: entry._id }, { $inc: { repliesCount: 1 } });
    return res.status(201).json({ id: reply._id, entryId: reply.entryId, content: reply.content, createdAt: reply.createdAt, authorId: reply.authorId });
  } catch (err) {
    console.error('POST /api/entries/:id/replies error:', err);
    return res.status(500).json({ error: 'INTERNAL_ERROR' });
  }
});

// List replies
app.get('/api/entries/:id/replies', async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.isValidObjectId(id)) return res.status(400).json({ error: 'INVALID_ID' });
    const page = Math.max(1, parseInt(req.query.page || '1', 10));
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit || '20', 10)));

    const items = await Reply.find({ entryId: id })
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .lean();
    return res.json({ page, limit, items });
  } catch (err) {
    console.error('GET /api/entries/:id/replies error:', err);
    return res.status(500).json({ error: 'INTERNAL_ERROR' });
  }
});

// ----- Start -----
app.listen(PORT, () => {
  console.log(`Server listening on http://localhost:${PORT}`);
});

// ---- Notification helper ----
async function sendPush(toToken, title, body, data) {
  if (!admin || !admin.apps || !admin.apps.length) return;
  try {
    await admin.messaging().send({ token: toToken, notification: { title, body }, data });
  } catch (err) {
    console.error('FCM send error:', err && err.message);
  }
}


