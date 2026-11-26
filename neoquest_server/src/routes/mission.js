// routes/mission.js
// Mission Upload System APIs for NeoQuest
// Handles route uploads, photo uploads, and mission completion
// API Endpoints created:
//
// POST /api/mission/upload-route - GPS Route Upload
// POST /api/mission/upload-photos - Photo Evidence Upload
// POST /api/mission/complete - Mission Completion
// GET /api/mission/upload-status/:playerToken - Upload Status Check
// GET /api/mission/leaderboard/:gameId? - Leaderboard & Rankings
// GET /api/mission/admin/all-status - Admin Overview
//
// 20250712 10:14 V1.0 File created
// 20250801 - Fixed pathToRegexp error with optional route parameters
//          - FIXED FOR EXPRESS 5.x - Route parameter syntax corrected
// routes/mission.js
// Mission Upload System APIs for NeoQuest
// Handles route uploads, photo uploads, and mission completion
// 
// FIXED FOR EXPRESS 5.x - Route parameter syntax corrected
// 20250801 - Fixed pathToRegexp error with optional route parameters
//          - Express 5 compatiblity implemented

const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;

// Database connection: gemeinsamer Pool aus config/database.js (Zugangsdaten aus .env)
const { pool } = require('../config/database');
const { requireAdmin } = require('../middleware/adminAuth');

// Configure multer for mission uploads
const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    const playerToken = req.body.playerToken || 'unknown';
    const uploadDir = path.join(__dirname, '../uploads/missions', playerToken);
    
    try {
      await fs.mkdir(uploadDir, { recursive: true });
      cb(null, uploadDir);
    } catch (error) {
      console.error('Error creating upload directory:', error);
      cb(error, null);
    }
  },
  filename: (req, file, cb) => {
    const timestamp = Date.now();
    const ext = path.extname(file.originalname);
    const basename = path.basename(file.originalname, ext);
    cb(null, `${file.fieldname}_${basename}_${timestamp}${ext}`);
  }
});

const upload = multer({ 
  storage: storage,
  limits: { 
    fileSize: 50 * 1024 * 1024, // 50MB limit
    files: 20 // Max 20 files per upload
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif|mp4|mov|pdf|txt|json/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);
    
    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only images, videos, and documents allowed.'));
    }
  }
});

// ===============================================
// ROUTE UPLOAD API
// ===============================================

/**
 * POST /api/mission/upload-route
 * Upload GPS route data for a player
 */
router.post('/upload-route', async (req, res) => {
  const client = await pool.connect();
  
  try {
    const { playerToken, routeData, sessionId } = req.body;
    
    if (!playerToken || !routeData) {
      return res.status(400).json({ 
        error: 'Missing required fields: playerToken, routeData' 
      });
    }
    
    const playerResult = await client.query(
      'SELECT id, name, game_id FROM neoquest.players WHERE token = $1',
      [playerToken]
    );
    
    if (playerResult.rows.length === 0) {
      return res.status(404).json({ error: 'Player not found' });
    }
    
    const player = playerResult.rows[0];
    const playerId = player.id;
    
    await client.query('BEGIN');
    
    const uploadResult = await client.query(`
      INSERT INTO neoquest.mission_uploads (player_id, upload_type, upload_status, metadata)
      VALUES ($1, 'route', 'complete', $2)
      ON CONFLICT (player_id, upload_type) 
      DO UPDATE SET 
        upload_status = 'complete',
        metadata = $2,
        uploaded_at = CURRENT_TIMESTAMP
      RETURNING id
    `, [playerId, JSON.stringify({ 
      sessionId, 
      routeData,
      uploadedAt: new Date().toISOString()
    })]);
    
    const existingResult = await client.query(
      'SELECT id FROM neoquest.mission_results WHERE player_id = $1',
      [playerId]
    );
    
    if (existingResult.rows.length > 0) {
      await client.query(`
        UPDATE neoquest.mission_results  
        SET 
          route_data = $1, 
          total_distance_meters = $2, 
          total_time_seconds = $3,
          updated_at = CURRENT_TIMESTAMP
        WHERE player_id = $4
      `, [
        JSON.stringify(routeData.route || []),
        routeData.totalDistance || 0,
        routeData.totalTime || 0,
        playerId
      ]);
    } else {
      await client.query(`
        INSERT INTO neoquest.mission_results 
        (player_id, game_id, route_data, total_distance_meters, total_time_seconds)
        VALUES ($1, $2, $3, $4, $5)
      `, [
        playerId,
        player.game_id || 1,
        JSON.stringify(routeData.route || []),
        routeData.totalDistance || 0,
        routeData.totalTime || 0
      ]);
    }
    
    await client.query('COMMIT');
    
    res.json({ 
      success: true, 
      uploadId: uploadResult.rows[0].id,
      message: 'Route uploaded successfully',
      player: {
        id: playerId,
        name: player.name,
        token: playerToken
      },
      routeStats: {
        totalDistance: routeData.totalDistance,
        totalTime: routeData.totalTime,
        pointCount: routeData.route?.length || 0
      }
    });
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Route upload error:', error);
    res.status(500).json({ 
      error: 'Failed to upload route',
      details: error.message 
    });
  } finally {
    client.release();
  }
});

// ===============================================
// PHOTO UPLOAD API
// ===============================================

/**
 * POST /api/mission/upload-photos
 * Upload photo evidence with metadata
 */
router.post('/upload-photos', upload.array('photos', 10), async (req, res) => {
  const client = await pool.connect();
  
  try {
    const { playerToken, photoMetadata } = req.body;
    const photos = req.files || [];
    
    if (!playerToken) {
      return res.status(400).json({ error: 'Missing playerToken' });
    }
    
    if (photos.length === 0) {
      return res.status(400).json({ error: 'No photos uploaded' });
    }
    
    const playerResult = await client.query(
      'SELECT id, name FROM neoquest.players WHERE token = $1',
      [playerToken]
    );
    
    if (playerResult.rows.length === 0) {
      return res.status(404).json({ error: 'Player not found' });
    }
    
    const player = playerResult.rows[0];
    const playerId = player.id;
    
    let metadata = [];
    try {
      metadata = JSON.parse(photoMetadata || '[]');
    } catch (parseError) {
      console.warn('Could not parse photo metadata, using defaults');
    }
    
    await client.query('BEGIN');
    
    const photoResults = [];
    for (let i = 0; i < photos.length; i++) {
      const file = photos[i];
      const meta = metadata[i] || {};
      
      const uploadResult = await client.query(`
        INSERT INTO neoquest.mission_uploads (player_id, upload_type, upload_status, file_path, file_size, metadata)
        VALUES ($1, 'photos', 'complete', $2, $3, $4)
        RETURNING id
      `, [
        playerId,
        file.path,
        file.size,
        JSON.stringify({
          originalName: file.originalname,
          filename: file.filename,
          mimetype: file.mimetype,
          checkpointId: meta.checkpointId,
          checkpointName: meta.checkpointName,
          capturedAt: meta.capturedAt,
          latitude: meta.latitude,
          longitude: meta.longitude,
          uploadedAt: new Date().toISOString()
        })
      ]);
      
      photoResults.push({
        uploadId: uploadResult.rows[0].id,
        filename: file.filename,
        originalName: file.originalname,
        size: file.size,
        checkpointId: meta.checkpointId,
        checkpointName: meta.checkpointName
      });
    }
    
    const existingResult = await client.query(
      'SELECT id, photos_taken FROM neoquest.mission_results WHERE player_id = $1',
      [playerId]
    );
    
    if (existingResult.rows.length > 0) {
      const existingPhotos = existingResult.rows[0].photos_taken || [];
      const updatedPhotos = [...existingPhotos, ...photoResults];
      
      await client.query(`
        UPDATE neoquest.mission_results 
        SET photos_taken = $1, updated_at = CURRENT_TIMESTAMP
        WHERE player_id = $2
      `, [JSON.stringify(updatedPhotos), playerId]);
    } else {
      await client.query(`
        INSERT INTO neoquest.mission_results (player_id, game_id, photos_taken)
        VALUES ($1, $2, $3)
      `, [playerId, 1, JSON.stringify(photoResults)]);
    }
    
    await client.query('COMMIT');
    
    res.json({ 
      success: true, 
      photosUploaded: photoResults.length,
      message: `${photoResults.length} photos uploaded successfully`,
      results: photoResults,
      player: {
        id: playerId,
        name: player.name,
        token: playerToken
      }
    });
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Photo upload error:', error);
    res.status(500).json({ 
      error: 'Failed to upload photos',
      details: error.message 
    });
  } finally {
    client.release();
  }
});

// ===============================================
// MISSION COMPLETION API
// ===============================================

/**
 * POST /api/mission/complete
 * Mark mission as complete and calculate final score
 */
router.post('/complete', async (req, res) => {
  const client = await pool.connect();
  
  try {
    const { 
      playerToken, 
      checkpointsReached, 
      finalScore, 
      completionTime,
      totalDistance,
      totalTime 
    } = req.body;
    
    if (!playerToken || finalScore === undefined) {
      return res.status(400).json({ 
        error: 'Missing required fields: playerToken, finalScore' 
      });
    }
    
    const playerResult = await client.query(
      'SELECT id, name, game_id FROM neoquest.players WHERE token = $1',
      [playerToken]
    );
    
    if (playerResult.rows.length === 0) {
      return res.status(404).json({ error: 'Player not found' });
    }
    
    const player = playerResult.rows[0];
    const playerId = player.id;
    
    await client.query('BEGIN');
    
    const completionTimestamp = completionTime ? new Date(completionTime) : new Date();
    
    await client.query(`
      UPDATE neoquest.players 
      SET 
        mission_completed = true, 
        mission_upload_status = 'complete',
        final_mission_score = $1,
        mission_completion_timestamp = $2,
        total_score = GREATEST(total_score, $1),
        game_completed = true
      WHERE id = $3
    `, [finalScore, completionTimestamp, playerId]);
    
    await client.query(`
      UPDATE neoquest.mission_results 
      SET 
        checkpoints_reached = $1, 
        final_score = $2, 
        completion_time = $3,
        total_distance_meters = COALESCE(total_distance_meters, $4),
        total_time_seconds = COALESCE(total_time_seconds, $5),
        updated_at = CURRENT_TIMESTAMP
      WHERE player_id = $6
    `, [
      JSON.stringify(checkpointsReached || []),
      finalScore,
      completionTimestamp,
      totalDistance || 0,
      totalTime || 0,
      playerId
    ]);
    
    await client.query(`
      INSERT INTO neoquest.mission_uploads (player_id, upload_type, upload_status, metadata)
      VALUES ($1, 'complete', 'complete', $2)
      ON CONFLICT (player_id, upload_type) 
      DO UPDATE SET 
        upload_status = 'complete',
        metadata = $2,
        uploaded_at = CURRENT_TIMESTAMP
    `, [playerId, JSON.stringify({ 
      finalScore, 
      completionTime: completionTimestamp.toISOString(), 
      checkpointsReached,
      totalDistance,
      totalTime
    })]);
    
    await client.query('COMMIT');
    
    res.json({ 
      success: true, 
      message: 'Mission completed successfully',
      player: {
        id: playerId,
        name: player.name,
        token: playerToken
      },
      results: {
        finalScore: finalScore,
        completionTime: completionTimestamp.toISOString(),
        checkpointsReached: checkpointsReached?.length || 0,
        totalDistance: totalDistance,
        totalTime: totalTime
      }
    });
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Mission completion error:', error);
    res.status(500).json({ 
      error: 'Failed to complete mission',
      details: error.message 
    });
  } finally {
    client.release();
  }
});

// ===============================================
// UPLOAD STATUS API
// ===============================================

/**
 * GET /api/mission/upload-status/:playerToken
 * Check upload progress and status for a player
 */
router.get('/upload-status/:playerToken', async (req, res) => {
  const client = await pool.connect();
  
  try {
    const { playerToken } = req.params;
    
    const statusResult = await client.query(`
      SELECT * FROM neoquest.upload_statistics WHERE player_token = $1
    `, [playerToken]);
    
    if (statusResult.rows.length === 0) {
      return res.status(404).json({ error: 'Player not found' });
    }
    
    const status = statusResult.rows[0];
    
    const uploadsResult = await client.query(`
      SELECT upload_type, upload_status, uploaded_at, file_size, metadata
      FROM neoquest.mission_uploads 
      WHERE player_id = $1 
      ORDER BY uploaded_at DESC
    `, [status.player_id]);
    
    const uploadProgress = {
      route: uploadsResult.rows.some(u => u.upload_type === 'route' && u.upload_status === 'complete'),
      photos: uploadsResult.rows.filter(u => u.upload_type === 'photos' && u.upload_status === 'complete').length,
      complete: uploadsResult.rows.some(u => u.upload_type === 'complete' && u.upload_status === 'complete')
    };
    
    res.json({
      success: true,
      player: {
        id: status.player_id,
        name: status.player_name,
        token: status.player_token,
        email: status.player_email,
        gameId: status.game_id,
        gameTitle: status.game_title
      },
      missionStatus: {
        completed: status.mission_completed,
        uploadStatus: status.mission_upload_status,
        finalScore: status.final_mission_score,
        totalScore: status.total_score,
        completionTime: status.mission_completion_timestamp,
        completionTimeSeconds: status.completion_time_seconds
      },
      uploadProgress: uploadProgress,
      uploads: uploadsResult.rows,
      missionResults: {
        totalDistance: status.total_distance_meters,
        totalTime: status.total_time_seconds,
        resultCompletionTime: status.result_completion_time
      },
      uploadTiming: {
        lastUpload: status.last_upload_at,
        firstUpload: status.first_upload_at
      }
    });
    
  } catch (error) {
    console.error('Upload status error:', error);
    res.status(500).json({ 
      error: 'Failed to get upload status',
      details: error.message 
    });
  } finally {
    client.release();
  }
});

// ===============================================
// LEADERBOARD API
// ===============================================

/**
 * GET /api/mission/leaderboard (all games)
 * GET /api/mission/leaderboard/:gameId (specific game)
 */
router.get('/leaderboard', async (req, res) => {
  await getLeaderboard(req, res, null);
});

router.get('/leaderboard/:gameId', async (req, res) => {
  await getLeaderboard(req, res, req.params.gameId);
});

async function getLeaderboard(req, res, gameId) {
  const client = await pool.connect();
  
  try {
    const limit = parseInt(req.query.limit) || 50;
    
    let query = `
      SELECT 
        player_name,
        player_token,
        final_mission_score,
        completion_time_seconds,
        mission_completion_timestamp,
        total_distance_meters,
        game_id,
        ROW_NUMBER() OVER (ORDER BY final_mission_score DESC, completion_time_seconds ASC) as rank
      FROM neoquest.upload_statistics 
      WHERE mission_completed = true
    `;
    
    const params = [];
    
    if (gameId) {
      query += ` AND game_id = $1`;
      params.push(gameId);
      query += ` ORDER BY final_mission_score DESC, completion_time_seconds ASC LIMIT $2`;
      params.push(limit);
    } else {
      query += ` ORDER BY final_mission_score DESC, completion_time_seconds ASC LIMIT $1`;
      params.push(limit);
    }
    
    const leaderboardResult = await client.query(query, params);
    
    const statsQuery = gameId 
      ? `SELECT COUNT(*) as total_players, AVG(final_mission_score) as avg_score FROM neoquest.upload_statistics WHERE game_id = $1`
      : `SELECT COUNT(*) as total_players, AVG(final_mission_score) as avg_score FROM neoquest.upload_statistics`;
    
    const statsParams = gameId ? [gameId] : [];
    const statsResult = await client.query(statsQuery, statsParams);
    
    res.json({
      success: true,
      gameId: gameId,
      leaderboard: leaderboardResult.rows,
      statistics: {
        totalPlayers: parseInt(statsResult.rows[0].total_players),
        averageScore: parseFloat(statsResult.rows[0].avg_score) || 0,
        entriesShown: leaderboardResult.rows.length
      },
      generatedAt: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Leaderboard error:', error);
    res.status(500).json({ 
      error: 'Failed to get leaderboard',
      details: error.message 
    });
  } finally {
    client.release();
  }
}

// ===============================================
// ADMIN STATUS API
// ===============================================

/**
 * GET /api/mission/admin/all-status
 * Get upload status for all players (admin endpoint)
 */
router.get('/admin/all-status', requireAdmin, async (req, res) => {
  const client = await pool.connect();
  
  try {
    const statusResult = await client.query(`
      SELECT 
        player_id,
        player_name,
        player_token,
        game_id,
        mission_completed,
        mission_upload_status,
        final_mission_score,
        route_uploaded,
        photos_uploaded,
        mission_upload_complete,
        registered_at,
        last_upload_at
      FROM neoquest.upload_statistics 
      ORDER BY registered_at DESC
    `);
    
    const statusSummary = {
      pending: statusResult.rows.filter(p => p.mission_upload_status === 'pending').length,
      uploading: statusResult.rows.filter(p => p.mission_upload_status === 'uploading').length,
      complete: statusResult.rows.filter(p => p.mission_upload_status === 'complete').length,
      failed: statusResult.rows.filter(p => p.mission_upload_status === 'failed').length
    };
    
    res.json({
      success: true,
      players: statusResult.rows,
      summary: statusSummary,
      totalPlayers: statusResult.rows.length,
      generatedAt: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Admin status error:', error);
    res.status(500).json({ 
      error: 'Failed to get admin status',
      details: error.message 
    });
  } finally {
    client.release();
  }
});

// Error handling middleware
router.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File too large. Maximum size is 50MB.' });
    }
    if (error.code === 'LIMIT_FILE_COUNT') {
      return res.status(400).json({ error: 'Too many files. Maximum is 10 files per upload.' });
    }
  }
  
  console.error('Mission upload error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    details: error.message 
  });
});

module.exports = router;