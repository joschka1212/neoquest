// neoquest_server/src/services/uploadService.js
/**
 * Upload Service
 * Handle file uploads and result processing
 */

const fs = require('fs').promises;
const path = require('path');
const sharp = require('sharp');
const { v4: uuidv4 } = require('uuid');
const { query, transaction } = require('../config/database');
const logger = require('../utils/logger');

// Upload directories
const UPLOAD_DIR = process.env.UPLOAD_DIR || './uploads';
const MEDIA_DIR = process.env.MEDIA_DIR || './media';
const TEMP_DIR = process.env.TEMP_DIR || './temp';

/**
 * Process complete game results upload
 * @param {number} playerId Player ID
 * @param {Object} gameResults Game results data
 * @param {Array} files Uploaded files
 * @returns {Promise<Object>} Processing result
 */
async function processGameResults(playerId, gameResults, files) {
  try {
    logger.info('Processing game results', {
      player_id: playerId,
      has_gps_data: !!gameResults.gps_track,
      has_quiz_data: !!gameResults.quiz_results,
      files_count: files.length
    });

    // Start transaction for atomic processing
    return await transaction(async (client) => {
      // Create upload queue entry
      const queuePosition = await getNextQueuePosition();
      
      const uploadId = uuidv4();
      
      // Insert into upload queue
      const queueResult = await client.query(`
        INSERT INTO neoquest.upload_queue (player_id, upload_type, queue_position, status)
        VALUES ($1, 'game_results', $2, 'processing')
        RETURNING id, queue_position
      `, [playerId, queuePosition]);

      const queueId = queueResult.rows[0].id;

      try {
        // Process different data types
        const processedFiles = [];
        
        // Process GPS track
        if (gameResults.gps_track && gameResults.gps_track.length > 0) {
          await processGPSTrack(playerId, gameResults.gps_track, gameResults.game_id);
        }

        // Process quiz results
        if (gameResults.quiz_results && gameResults.quiz_results.length > 0) {
          await processQuizResults(playerId, gameResults.quiz_results);
        }

        // Process uploaded files (photos)
        if (files && files.length > 0) {
          for (const file of files) {
            const processedFile = await processUploadedFile(file, playerId, uploadId);
            processedFiles.push(processedFile);
          }
        }

        // Update player completion status
        if (gameResults.completion_time || gameResults.game_completed) {
          await updatePlayerCompletion(client, playerId, gameResults);
        }

        // Mark upload as completed
        await client.query(`
          UPDATE neoquest.upload_queue 
          SET status = 'completed', processed_at = CURRENT_TIMESTAMP
          WHERE id = $1
        `, [queueId]);

        logger.info('Game results processed successfully', {
          player_id: playerId,
          upload_id: uploadId,
          processed_files: processedFiles.length
        });

        return {
          success: true,
          upload_id: uploadId,
          queue_position: queuePosition,
          processed_files: processedFiles.length,
          gps_points: gameResults.gps_track?.length || 0,
          quiz_answers: gameResults.quiz_results?.length || 0
        };

      } catch (error) {
        // Mark upload as failed
        await client.query(`
          UPDATE neoquest.upload_queue 
          SET status = 'failed', error_message = $1, processed_at = CURRENT_TIMESTAMP
          WHERE id = $2
        `, [error.message, queueId]);

        throw error;
      }
    });

  } catch (error) {
    logger.error('Failed to process game results', {
      player_id: playerId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Process GPS tracking data
 * @param {number} playerId Player ID
 * @param {Array} gpsTrack GPS track points
 * @param {number} gameId Game ID
 */
async function processGPSTrack(playerId, gpsTrack, gameId) {
  logger.debug('Processing GPS track', {
    player_id: playerId,
    points_count: gpsTrack.length
  });

  // Insert GPS points in batches
  const batchSize = 100;
  for (let i = 0; i < gpsTrack.length; i += batchSize) {
    const batch = gpsTrack.slice(i, i + batchSize);
    
    // Build bulk insert query
    const values = batch.map((point, index) => {
      const paramOffset = index * 6;
      return `($${paramOffset + 1}, $${paramOffset + 2}, $${paramOffset + 3}, $${paramOffset + 4}, $${paramOffset + 5}, $${paramOffset + 6})`;
    }).join(', ');

    const params = batch.flatMap(point => [
      playerId,
      gameId,
      point.latitude,
      point.longitude,
      point.accuracy || null,
      point.timestamp,
      point.altitude || null
    ]);

    await query(`
      INSERT INTO neoquest.gps_tracks (player_id, game_id, latitude, longitude, accuracy, timestamp, altitude)
      VALUES ${values}
    `, params);
  }

  logger.info('GPS track processed', {
    player_id: playerId,
    total_points: gpsTrack.length
  });
}

/**
 * Process quiz results
 * @param {number} playerId Player ID
 * @param {Array} quizResults Quiz answers
 */
async function processQuizResults(playerId, quizResults) {
  logger.debug('Processing quiz results', {
    player_id: playerId,
    answers_count: quizResults.length
  });

  for (const answer of quizResults) {
    try {
      // Get correct answer from database
      const puzzleResult = await query(`
        SELECT answer, points FROM neoquest.puzzles WHERE id = $1
      `, [answer.puzzle_id]);

      if (puzzleResult.rows.length === 0) {
        logger.warn('Puzzle not found for answer', {
          puzzle_id: answer.puzzle_id,
          player_id: playerId
        });
        continue;
      }

      const puzzle = puzzleResult.rows[0];
      const correctAnswer = puzzle.answer.toLowerCase().trim();
      const givenAnswer = answer.given_answer.toLowerCase().trim();
      const isCorrect = correctAnswer === givenAnswer;
      const pointsEarned = isCorrect ? puzzle.points : 0;

      // Insert quiz result
      await query(`
        INSERT INTO neoquest.quiz_results 
        (player_id, puzzle_id, given_answer, is_correct, points_earned, answered_at)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (player_id, puzzle_id) 
        DO UPDATE SET 
          given_answer = EXCLUDED.given_answer,
          is_correct = EXCLUDED.is_correct,
          points_earned = EXCLUDED.points_earned,
          answered_at = EXCLUDED.answered_at
      `, [
        playerId,
        answer.puzzle_id,
        answer.given_answer,
        isCorrect,
        pointsEarned,
        answer.answered_at || new Date().toISOString()
      ]);

    } catch (error) {
      logger.error('Failed to process quiz answer', {
        player_id: playerId,
        puzzle_id: answer.puzzle_id,
        error: error.message
      });
    }
  }

  // Update total score for player
  const scoreResult = await query(`
    SELECT SUM(points_earned) as total_score
    FROM neoquest.quiz_results
    WHERE player_id = $1
  `, [playerId]);

  const totalScore = scoreResult.rows[0].total_score || 0;

  await query(`
    UPDATE neoquest.players 
    SET total_score = $1
    WHERE id = $2
  `, [totalScore, playerId]);

  logger.info('Quiz results processed', {
    player_id: playerId,
    total_score: totalScore
  });
}

/**
 * Process uploaded file
 * @param {Object} file Multer file object
 * @param {number} playerId Player ID
 * @param {string} uploadId Upload session ID
 * @returns {Promise<Object>} Processed file info
 */
async function processUploadedFile(file, playerId, uploadId) {
  const fileId = uuidv4();
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  
  // Create player directory
  const playerDir = path.join(UPLOAD_DIR, `player_${playerId}`, uploadId);
  await fs.mkdir(playerDir, { recursive: true });

  // Determine file type and processing
  const isImage = file.mimetype.startsWith('image/');
  const extension = path.extname(file.originalname) || (isImage ? '.jpg' : '.bin');
  const filename = `${file.fieldname}_${timestamp}_${fileId}${extension}`;
  const filepath = path.join(playerDir, filename);

  try {
    if (isImage) {
      // Process image: resize and optimize
      await sharp(file.buffer)
        .resize(1920, 1920, { 
          fit: 'inside', 
          withoutEnlargement: true 
        })
        .jpeg({ 
          quality: 85,
          progressive: true 
        })
        .toFile(filepath);
    } else {
      // Save non-image files as-is
      await fs.writeFile(filepath, file.buffer);
    }

    // Save file metadata to database
    const fileResult = await query(`
      INSERT INTO neoquest.media_files 
      (filename, original_name, file_path, file_type, file_size, uploaded_by)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id
    `, [
      filename,
      file.originalname,
      filepath,
      file.mimetype,
      file.size,
      playerId
    ]);

    logger.info('File processed and saved', {
      file_id: fileResult.rows[0].id,
      filename: filename,
      original_name: file.originalname,
      size: file.size,
      player_id: playerId
    });

    return {
      file_id: fileResult.rows[0].id,
      filename: filename,
      original_name: file.originalname,
      file_type: file.mimetype,
      file_size: file.size,
      file_path: filepath
    };

  } catch (error) {
    logger.error('Failed to process file', {
      filename: file.originalname,
      player_id: playerId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Update player completion status
 * @param {Object} client Database client
 * @param {number} playerId Player ID
 * @param {Object} gameResults Game results
 */
async function updatePlayerCompletion(client, playerId, gameResults) {
  const updates = [];
  const params = [playerId];
  let paramCount = 1;

  if (gameResults.completion_time) {
    updates.push(`completion_time = $${++paramCount}`);
    params.push(gameResults.completion_time);
  }

  if (gameResults.game_completed !== undefined) {
    updates.push(`game_completed = $${++paramCount}`);
    params.push(gameResults.game_completed);
  }

  if (updates.length > 0) {
    await client.query(`
      UPDATE neoquest.players 
      SET ${updates.join(', ')}
      WHERE id = $1
    `, params);

    // Also update player_games table
    await client.query(`
      UPDATE neoquest.player_games 
      SET completed_at = CASE WHEN $2 = true THEN CURRENT_TIMESTAMP ELSE completed_at END
      WHERE player_id = $1
    `, [playerId, gameResults.game_completed]);
  }
}

/**
 * Get next queue position
 * @returns {Promise<number>} Next queue position
 */
async function getNextQueuePosition() {
  const result = await query(`
    SELECT COALESCE(MAX(queue_position), 0) + 1 as next_position
    FROM neoquest.upload_queue 
    WHERE status IN ('pending', 'processing')
  `);
  
  return result.rows[0].next_position;
}

/**
 * Process single GPS track upload
 * @param {number} playerId Player ID
 * @param {Array} gpsData GPS data points
 * @param {number} gameId Game ID
 * @returns {Promise<Object>} Processing result
 */
async function processGPSUpload(playerId, gpsData, gameId) {
  try {
    await processGPSTrack(playerId, gpsData, gameId);
    
    return {
      success: true,
      points_processed: gpsData.length,
      message: 'GPS track uploaded successfully'
    };
  } catch (error) {
    logger.error('Failed to process GPS upload', {
      player_id: playerId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Process single photo upload
 * @param {Object} file Photo file
 * @param {number} playerId Player ID
 * @param {string} checkpointId Optional checkpoint ID
 * @returns {Promise<Object>} Processing result
 */
async function processPhotoUpload(file, playerId, checkpointId = null) {
  try {
    const uploadId = uuidv4();
    const processedFile = await processUploadedFile(file, playerId, uploadId);
    
    // If checkpoint ID provided, link photo to checkpoint visit
    if (checkpointId) {
      await query(`
        INSERT INTO neoquest.checkpoint_visits (player_id, checkpoint_id, photo_path, visited_at)
        VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
        ON CONFLICT (player_id, checkpoint_id)
        DO UPDATE SET photo_path = EXCLUDED.photo_path, visited_at = EXCLUDED.visited_at
      `, [playerId, checkpointId, processedFile.file_path]);
    }
    
    return {
      success: true,
      file: processedFile,
      message: 'Photo uploaded successfully'
    };
  } catch (error) {
    logger.error('Failed to process photo upload', {
      player_id: playerId,
      checkpoint_id: checkpointId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Get upload queue status for player
 * @param {number} playerId Player ID
 * @returns {Promise<Object>} Queue status
 */
async function getPlayerQueueStatus(playerId) {
  const result = await query(`
    SELECT 
      MIN(queue_position) as position,
      COUNT(*) as pending_uploads,
      MIN(created_at) as oldest_upload
    FROM neoquest.upload_queue 
    WHERE player_id = $1 AND status IN ('pending', 'processing')
  `, [playerId]);

  const playerQueue = result.rows[0];

  const totalResult = await query(`
    SELECT COUNT(*) as total_in_queue
    FROM neoquest.upload_queue 
    WHERE status IN ('pending', 'processing')
  `);

  const totalInQueue = parseInt(totalResult.rows[0].total_in_queue);
  const position = parseInt(playerQueue.position) || 0;
  const estimatedWait = Math.max(0, (position - 1) * 2); // 2 minutes per position

  return {
    position: position,
    pending_uploads: parseInt(playerQueue.pending_uploads) || 0,
    total_in_queue: totalInQueue,
    estimated_wait_minutes: estimatedWait,
    oldest_upload: playerQueue.oldest_upload
  };
}

module.exports = {
  processGameResults,
  processGPSUpload,
  processPhotoUpload,
  getPlayerQueueStatus,
  processGPSTrack,
  processQuizResults,
  processUploadedFile
};