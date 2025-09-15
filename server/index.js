require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const multer = require('multer');

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

    // Random feed
    const sampled = await Entry.aggregate([
      { $sample: { size: limit } },
      { $project: { content: 1, hearts: 1, repliesCount: 1, createdAt: 1, emotion: 1, imageUrl: 1 } },
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
    const { id } = req.params;
    if (!mongoose.isValidObjectId(id)) return res.status(400).json({ error: 'INVALID_ID' });
    const updated = await Entry.findByIdAndUpdate(id, { $inc: { hearts: 1 } }, { new: true }).lean();
    if (!updated) return res.status(404).json({ error: 'NOT_FOUND' });
    return res.json({ id: updated._id, hearts: updated.hearts });
  } catch (err) {
    console.error('POST /api/entries/:id/heart error:', err);
    return res.status(500).json({ error: 'INTERNAL_ERROR' });
  }
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


