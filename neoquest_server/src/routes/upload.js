// neoquest_server/src/routes/upload.js

/**
 * Upload Routes
 * Handle file uploads and game result submissions
 */

const express = require('express');
const multer = require('multer');
const { body, validationResult } = require('express-validator');
const { asyncHandler } = require('../middleware/errorHandler');
const { validateToken } = require('../utils/tokenGenerator');
const { 
  processGameResults, 
  processGPSUpload, 
  processPhotoUpload,
  getPlayerQueueStatus 
} = require('../services/uploadService');
const logger = require('../utils/logger');

const router = express.Router();

// Configure multer for file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: parseInt(process.env.UPLOAD_MAX_SIZE) || 50 * 1024 * 1024, // 50MB
    files: 20 // Maximum 20 files per upload
  },
  fileFilter: (req, file, cb) => {
    // Allow images and GPS/JSON files
    const allowedTypes = [
      'image/jpeg',
      'image/jpg', 
      'image/png',
      'image/webp',
      'application/json',
      'text/plain'
    ];
    
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`File type ${file.mimetype} not allowed`), false);
    }
  }
});

/**
 * Token validation middleware
 */
async function requireValidToken(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '') || req.body.token;
  
  if (!token) {
    return res.status(401).json({
      error: 'Token required',
      message: 'Provide token in Authorization header or request body'
    });
  }

  const validation = await validateToken(token);
  
  if (!validation.valid) {
    return res.status(401).json({
      error: 'Invalid token',
      message: validation.error
    });
  }

  req.player = validation.player;
  next();
}

/**
 * Upload complete game results
 * POST /api/upload/results
 */
router.post('/results', upload.array('files', 20), requireValidToken, [
  body('game_results').isString().withMessage('Game results data is required'),
  body('completion_time').optional().isInt({ min: 0 }),
  body('game_completed').optional().isBoolean()
], asyncHandler(async (req, res) => {
  // Check validation errors
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }

  const playerId = req.player.id;
  const files = req.files || [];
  
  let gameResults;
  try {
    gameResults = JSON.parse(req.body.game_results);
  } catch (error) {
    return res.status(400).json({
      error: 'Invalid game results format',
      message: 'game_results must be valid JSON'
    });
  }

  // Add completion info from form data
  if (req.body.completion_time) {
    gameResults.completion_time = parseInt(req.body.completion_time);
  }
  if (req.body.game_completed !== undefined) {
    gameResults.game_completed = req.body.game_completed === 'true';
  }
  if (!gameResults.game_id) {
    gameResults.game_id = req.player.game_id;
  }

  logger.info('Processing complete game results upload', {
    player_id: playerId,
    game_id: gameResults.game_id,
    files_count: files.length,
    has_gps: !!gameResults.gps_track,
    has_quiz: !!gameResults.quiz_results,
    completion_time: gameResults.completion_time
  });

  try {
    const result = await processGameResults(playerId, gameResults, files);

    res.json({
      success: true,
      message: 'Game results uploaded successfully',
      data: {
        upload_id: result.upload_id,
        queue_position: result.queue_position,
        processed_files: result.processed_files,
        gps_points: result.gps_points,
        quiz_answers: result.quiz_answers
      }
    });

  } catch (error) {
    logger.error('Failed to process game results upload', {
      player_id: playerId,
      error: error.message
    });

    res.status(500).json({
      error: 'Upload processing failed',
      message: error.message
    });
  }
}));

/**
 * Upload GPS tracking data
 * POST /api/upload/gps-track
 */
router.post('/gps-track', requireValidToken, [
  body('gps_data').isArray().withMessage('GPS data must be an array'),
  body('gps_data.*.latitude').isFloat({ min: -90, max: 90 }),
  body('gps_data.*.longitude').isFloat({ min: -180, max: 180 }),
  body('gps_data.*.timestamp').isISO8601(),
  body('gps_data.*.accuracy').optional().isFloat({ min: 0 }),
  body('gps_data.*.altitude').optional().isFloat()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }

  const playerId = req.player.id;
  const gameId = req.player.game_id;
  const { gps_data } = req.body;

  logger.info('Processing GPS track upload', {
    player_id: playerId,
    game_id: gameId,
    points_count: gps_data.length
  });

  try {
    const result = await processGPSUpload(playerId, gps_data, gameId);

    res.json({
      success: true,
      message: result.message,
      data: {
        points_processed: result.points_processed
      }
    });

  } catch (error) {
    logger.error('Failed to process GPS upload', {
      player_id: playerId,
      error: error.message
    });

    res.status(500).json({
      error: 'GPS upload failed',
      message: error.message
    });
  }
}));

/**
 * Upload single photo
 * POST /api/upload/photo
 */
router.post('/photo', upload.single('photo'), requireValidToken, [
  body('checkpoint_id').optional().isInt({ min: 1 }),
  body('photo_type').optional().isIn(['checkpoint', 'success', 'selfie'])
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }

  if (!req.file) {
    return res.status(400).json({
      error: 'No photo provided',
      message: 'Photo file is required'
    });
  }

  const playerId = req.player.id;
  const { checkpoint_id, photo_type } = req.body;

  logger.info('Processing photo upload', {
    player_id: playerId,
    checkpoint_id: checkpoint_id,
    photo_type: photo_type,
    file_size: req.file.size,
    file_type: req.file.mimetype
  });

  try {
    const result = await processPhotoUpload(req.file, playerId, checkpoint_id);

    res.json({
      success: true,
      message: result.message,
      data: {
        file_id: result.file.file_id,
        filename: result.file.filename,
        file_size: result.file.file_size
      }
    });

  } catch (error) {
    logger.error('Failed to process photo upload', {
      player_id: playerId,
      error: error.message
    });

    res.status(500).json({
      error: 'Photo upload failed',
      message: error.message
    });
  }
}));

/**
 * Get upload queue status
 * GET /api/upload/queue-status
 */
router.get('/queue-status', requireValidToken, asyncHandler(async (req, res) => {
  const playerId = req.player.id;

  try {
    const queueStatus = await getPlayerQueueStatus(playerId);

    res.json({
      success: true,
      queue_status: queueStatus
    });

  } catch (error) {
    logger.error('Failed to get queue status', {
      player_id: playerId,
      error: error.message
    });

    res.status(500).json({
      error: 'Failed to get queue status',
      message: error.message
    });
  }
}));

/**
 * Get upload history for player
 * GET /api/upload/history
 */
router.get('/history', requireValidToken, asyncHandler(async (req, res) => {
  const playerId = req.player.id;

  const result = await query(`
    SELECT 
      id,
      upload_type,
      status,
      queue_position,
      created_at,
      processed_at,
      error_message
    FROM neoquest.upload_queue
    WHERE player_id = $1
    ORDER BY created_at DESC
    LIMIT 50
  `, [playerId]);

  res.json({
    success: true,
    uploads: result.rows
  });
}));

/**
 * Test upload endpoint
 * GET /api/upload/test
 */
router.get('/test', (req, res) => {
  res.json({ 
    message: 'Upload routes working!',
    timestamp: new Date().toISOString(),
    max_file_size: process.env.UPLOAD_MAX_SIZE || '50MB'
  });
});

module.exports = router;