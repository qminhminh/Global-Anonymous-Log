require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

// ----- Config -----
const app = express();
const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
  console.error('Missing MONGODB_URI in .env');
  process.exit(1);
}

app.use(cors({ origin: '*', methods: ['GET', 'POST', 'OPTIONS'], allowedHeaders: ['Content-Type'] }));
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
  },
  { timestamps: true }
);

const replySchema = new mongoose.Schema(
  {
    entryId: { type: mongoose.Schema.Types.ObjectId, ref: 'Entry', required: true, index: true },
    content: { type: String, required: true, trim: true, maxlength: 1000 },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

const Entry = mongoose.model('Entry', entrySchema);
const Reply = mongoose.model('Reply', replySchema);

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
app.get('/healthz', (req, res) => {
  return res.json({ ok: true, timestamp: Date.now() });
});

// Create entry (anonymous)
app.post('/api/entries', async (req, res) => {
  try {
    var errCode = validateEntryBody(req.body);
    if (errCode) return res.status(400).json({ error: errCode });
    const content = req.body.content.trim();
    const entry = await Entry.create({ content: content });
    return res.status(201).json({ id: entry._id, content: entry.content, hearts: entry.hearts, repliesCount: entry.repliesCount, createdAt: entry.createdAt });
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
      // Ensure deterministic shape
      { $project: { content: 1, hearts: 1, repliesCount: 1, createdAt: 1 } },
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
    var errCode = validateReplyBody(req.body);
    if (errCode) return res.status(400).json({ error: errCode });
    const content = req.body.content.trim();
    const entry = await Entry.findById(id).select('_id');
    if (!entry) return res.status(404).json({ error: 'NOT_FOUND' });

    const reply = await Reply.create({ entryId: entry._id, content });
    await Entry.updateOne({ _id: entry._id }, { $inc: { repliesCount: 1 } });
    return res.status(201).json({ id: reply._id, entryId: reply.entryId, content: reply.content, createdAt: reply.createdAt });
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


