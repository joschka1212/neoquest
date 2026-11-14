// neoquest_server/src/routes/game.js
/**
 * Game Routes
 * Handle game data and gameplay endpoints
 * 
 * FIXED FOR EXPRESS 5.x - Route parameter syntax corrected
 * 20250801 - Fixed pathToRegexp error with route parameters
 *          - Game Routes - Express 5.x Safe Version: Removed problematic wildcard routes
*/

/**
 * Game Routes API Endpoints
 * Complete list of all available endpoints in game.js
 * 
 * Base URL: /api/game
 * 
 * LEGACY ROUTES (Token Required):
 * ================================
 * GET  /api/game/data                    - Get game data for authenticated player
 * GET  /api/game/queue-status            - Get upload queue status for player
 * GET  /api/game/leaderboard             - Get leaderboard for competitive games
 * GET  /api/game/config                  - Get game configuration for player's game
 * POST /api/game/start                   - Start game session (mark as started)
 * GET  /api/game/test                    - Test endpoint to verify game routes
 * 
 * NEW GAME DATA DOWNLOAD API (Public):
 * ====================================
 * GET  /api/game/data/:game_id           - Download complete game package (no token required)
 * GET  /api/game/media/:game_slug/*      - Serve media files for specific game
 * 
 * AUTHENTICATION:
 * ==============
 * Token Required Routes: Use 'Authorization: Bearer <token>' header or '?token=<token>' query parameter
 * Public Routes: No authentication required
 * 
 * EXAMPLES:
 * =========
 * curl http://localhost:3000/api/game/data/1
 * curl http://localhost:3000/api/game/media/testgame1/intro/start_game.mp3
 * curl -H "Authorization: Bearer ABC123" http://localhost:3000/api/game/data
 * curl http://localhost:3000/api/game/leaderboard?token=ABC123
 *
 */
/**
 * Game Routes
 * Handle game data and gameplay endpoints
 */

const express = require('express');
const { validationResult } = require('express-validator');
const { asyncHandler } = require('../middleware/errorHandler');
const { validateToken } = require('../utils/tokenGenerator');
const { getGameDataForPlayer, getLeaderboard } = require('../services/gameDataService');
const logger = require('../utils/logger');
const { query } = require('../config/database');

const fs = require('fs').promises;
const path = require('path');

const router = express.Router();

/**
 * Token validation middleware
 */
async function requireValidToken(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '') || req.query.token;
  
  if (!token) {
    return res.status(401).json({
      error: 'Token required',
      message: 'Provide token in Authorization header or query parameter'
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

// ===============================================
// HELPER FUNCTIONS
// ===============================================

async function scanPuzzleDirectory(puzzlePath, puzzleId) {
  try {
    const files = await fs.readdir(puzzlePath);
    const puzzleData = {
      id: puzzleId,
      files: {
        main: null,
        hints: [],
        reward: null,
        solution: null,
        scoring: null
      },
      scoring_config: null
    };

    for (const file of files) {
      const filePath = path.join(puzzlePath, file);
      const stats = await fs.stat(filePath);
      
      if (!stats.isFile()) continue;

      if (file.includes('_main.')) {
        puzzleData.files.main = file;
      } else if (file.includes('_hint_')) {
        puzzleData.files.hints.push(file);
      } else if (file.includes('_reward.')) {
        puzzleData.files.reward = file;
      } else if (file.includes('_solution.')) {
        puzzleData.files.solution = file;
      } else if (file.includes('_scoring.json')) {
        puzzleData.files.scoring = file;
        
        try {
          const scoringContent = await fs.readFile(filePath, 'utf8');
          puzzleData.scoring_config = JSON.parse(scoringContent);
        } catch (error) {
          logger.warn(`Error loading scoring config for ${file}:`, error.message);
        }
      }
    }

    puzzleData.files.hints.sort((a, b) => {
      const aNum = parseInt(a.match(/_hint_(\d+)/)?.[1] || '0');
      const bNum = parseInt(b.match(/_hint_(\d+)/)?.[1] || '0');
      return aNum - bNum;
    });

    return puzzleData;
  } catch (error) {
    logger.error(`Error scanning puzzle directory ${puzzlePath}:`, error);
    return null;
  }
}

async function scanCheckpointFiles(checkpointPath) {
  try {
    const files = await fs.readdir(checkpointPath);
    const checkpointFiles = [];

    for (const file of files) {
      const filePath = path.join(checkpointPath, file);
      const stats = await fs.stat(filePath);
      
      if (stats.isFile()) {
        checkpointFiles.push(file);
      }
    }

    return checkpointFiles.sort();
  } catch (error) {
    logger.error(`Error scanning checkpoint directory ${checkpointPath}:`, error);
    return [];
  }
}

async function scanIntroFiles(introPath) {
  try {
    const files = await fs.readdir(introPath);
    const introFiles = [];

    for (const file of files) {
      const filePath = path.join(introPath, file);
      const stats = await fs.stat(filePath);
      
      if (stats.isFile()) {
        introFiles.push(file);
      }
    }

    return introFiles.sort();
  } catch (error) {
    logger.error(`Error scanning intro directory ${introPath}:`, error);
    return [];
  }
}

// ===============================================
// LEGACY ROUTES (Token Required)
// ===============================================

/**
 * Get complete game data for player
 * GET /api/game/data
 */
router.get('/data', requireValidToken, asyncHandler(async (req, res) => {
  const { mode } = req.query;
  const playerId = req.player.id;

  logger.info('Game data request', {
    player_id: playerId,
    player_name: req.player.name,
    requested_mode: mode,
    game_id: req.player.game_id
  });

  try {
    const gameData = await getGameDataForPlayer(playerId, mode);

    logger.info('Game data prepared successfully', {
      player_id: playerId,
      game_mode: gameData.metadata.game_mode,
      checkpoints_count: gameData.checkpoints.length,
      puzzles_count: gameData.puzzles.length
    });

    res.json({
      success: true,
      message: 'Game data retrieved successfully',
      data: gameData
    });

  } catch (error) {
    logger.error('Failed to prepare game data', {
      player_id: playerId,
      error: error.message
    });

    res.status(500).json({
      error: 'Failed to retrieve game data',
      message: error.message
    });
  }
}));

// ===============================================
// PUBLIC GAME DATA DOWNLOAD API
// ===============================================

/**
 * Download complete game data package
 * GET /api/game/data/:game_id
 */
router.get('/data/:game_id', asyncHandler(async (req, res) => {
  try {
    const gameId = parseInt(req.params.game_id);
    
    if (!gameId || gameId < 1) {
      return res.status(400).json({
        error: 'Invalid game ID',
        details: 'Game ID must be a positive integer'
      });
    }

    // Get game information from database
    const gameResult = await query(`
      SELECT g.id, g.name, g.description, g.game_type, g.complexity_level, 
             g.game_config, g.start_audio_path, g.is_active
      FROM neoquest.games g
      WHERE g.id = $1 AND g.is_active = TRUE
    `, [gameId]);

    if (gameResult.rows.length === 0) {
      return res.status(404).json({
        error: 'Game not found',
        details: `Game with ID ${gameId} not found or inactive`
      });
    }

    const game = gameResult.rows[0];

    // Get checkpoints from database
    const checkpointsResult = await query(`
      SELECT c.id, c.name, c.description, c.latitude, c.longitude, 
             c.checkpoint_order, c.checkpoint_type, c.radius, c.qr_code_content,
             c.is_required, c.min_stay_duration, c.checkpoint_config
      FROM neoquest.checkpoints c
      WHERE c.game_id = $1
      ORDER BY c.checkpoint_order ASC
    `, [gameId]);

    // Get puzzles from database
    const puzzlesResult = await query(`
      SELECT p.id, p.puzzle_id, p.title, p.question, p.puzzle_type, p.puzzle_config,
             p.checkpoint_id, p.points, p.max_attempts, p.time_limit, p.difficulty,
             p.unlock_condition, p.unlock_config, p.is_active,
             p.base_points, p.hint_penalty, p.time_bonus_max, 
             p.time_limit_minutes, p.has_time_limit, p.scoring_type
      FROM neoquest.puzzles p
      JOIN neoquest.checkpoints c ON p.checkpoint_id = c.id
      WHERE c.game_id = $1 AND p.is_active = TRUE
      ORDER BY c.checkpoint_order ASC, p.puzzle_id ASC
    `, [gameId]);

    // Determine game directory path
    const gameSlugMapping = {
      1: 'testgame1',
      2: 'testgame2'
    };
    
    const gameSlug = gameSlugMapping[gameId] || game.name.toLowerCase()
      .replace(/[^a-z0-9]/g, '_')
      .replace(/_+/g, '_')
      .replace(/^_|_$/g, '');
    
    const gameMediaPath = path.join(process.cwd(), 'media', 'games', gameSlug);

    // Scan media directories
    const puzzlesPath = path.join(gameMediaPath, 'puzzles');
    const checkpointsPath = path.join(gameMediaPath, 'checkpoints');
    const introPath = path.join(gameMediaPath, 'intro');

    // Collect puzzle media data
    const puzzleMediaData = [];
    for (const puzzle of puzzlesResult.rows) {
      const puzzleDir = puzzle.puzzle_id;
      const puzzlePath = path.join(puzzlesPath, puzzleDir);
      
      try {
        await fs.access(puzzlePath);
        const puzzleData = await scanPuzzleDirectory(puzzlePath, puzzle.id);
        if (puzzleData) {
          puzzleData.database_info = puzzle;
          puzzleData.directory_name = puzzleDir;
          
          puzzleData.final_scoring = {
            base_points: puzzle.base_points || 100,
            hint_penalty: puzzle.hint_penalty || 20,
            time_bonus_max: puzzle.time_bonus_max || 50,
            time_limit_minutes: puzzle.time_limit_minutes || 10,
            has_time_limit: puzzle.has_time_limit !== false,
            scoring_type: puzzle.scoring_type || 'standard',
            ...(puzzleData.scoring_config || {})
          };
          
          puzzleMediaData.push(puzzleData);
        }
      } catch (error) {
        // Puzzle directory not found - skip silently
      }
    }

    // Collect checkpoint and intro media files
    const checkpointFiles = await scanCheckpointFiles(checkpointsPath);
    const introFiles = await scanIntroFiles(introPath);

    // Build complete game package
    const gamePackage = {
      game: {
        id: game.id,
        name: game.name,
        description: game.description,
        game_type: game.game_type,
        complexity_level: game.complexity_level,
        game_config: game.game_config,
        start_audio_path: game.start_audio_path,
        media_base_url: `${req.protocol}://${req.get('host')}/api/game/media/${gameSlug}`
      },
      checkpoints: checkpointsResult.rows.map(checkpoint => ({
        ...checkpoint,
        media_files: checkpointFiles.filter(file => 
          file.startsWith(`checkpoint${String(checkpoint.checkpoint_order).padStart(3, '0')}`)
        )
      })),
      puzzles: puzzleMediaData,
      intro: {
        files: introFiles
      },
      download_info: {
        timestamp: new Date().toISOString(),
        total_puzzles: puzzleMediaData.length,
        total_checkpoints: checkpointsResult.rows.length,
        media_base_url: `${req.protocol}://${req.get('host')}/api/game/media/${gameSlug}`
      }
    };

    res.json({
      success: true,
      data: gamePackage
    });

  } catch (error) {
    logger.error('Game data download error', {
      game_id: req.params.game_id,
      error: error.message,
      stack: error.stack
    });
    
    res.status(500).json({
      error: 'Internal server error',
      details: 'Failed to load game data',
      debug_info: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
}));

/**
 * Serve media files for specific game types
 */
router.get('/media/:game_slug/puzzles/:puzzle_id/:filename', asyncHandler(async (req, res) => {
  const { game_slug, puzzle_id, filename } = req.params;
  const filePath = path.join(process.cwd(), 'media', 'games', game_slug, 'puzzles', puzzle_id, filename);
  
  try {
    await fs.access(filePath);
    res.sendFile(path.resolve(filePath));
  } catch (error) {
    res.status(404).json({ error: 'File not found' });
  }
}));

router.get('/media/:game_slug/checkpoints/:filename', asyncHandler(async (req, res) => {
  const { game_slug, filename } = req.params;
  const filePath = path.join(process.cwd(), 'media', 'games', game_slug, 'checkpoints', filename);
  
  try {
    await fs.access(filePath);
    res.sendFile(path.resolve(filePath));
  } catch (error) {
    res.status(404).json({ error: 'File not found' });
  }
}));

router.get('/media/:game_slug/intro/:filename', asyncHandler(async (req, res) => {
  const { game_slug, filename } = req.params;
  const filePath = path.join(process.cwd(), 'media', 'games', game_slug, 'intro', filename);
  
  try {
    await fs.access(filePath);
    res.sendFile(path.resolve(filePath));
  } catch (error) {
    res.status(404).json({ error: 'File not found' });
  }
}));

// ===============================================
// GAME MANAGEMENT ROUTES
// ===============================================

/**
 * Get queue status for uploads
 * GET /api/game/queue-status
 */
router.get('/queue-status', requireValidToken, asyncHandler(async (req, res) => {
  const playerId = req.player.id;

  const result = await query(`
    SELECT 
      MIN(queue_position) as position,
      COUNT(*) as total_pending,
      MIN(created_at) as oldest_upload
    FROM neoquest.upload_queue 
    WHERE player_id = $1 AND status = 'pending'
  `, [playerId]);

  const queueInfo = result.rows[0];

  const totalResult = await query(`
    SELECT COUNT(*) as total_in_queue
    FROM neoquest.upload_queue 
    WHERE status = 'pending'
  `);

  const totalInQueue = parseInt(totalResult.rows[0].total_in_queue);
  const position = parseInt(queueInfo.position) || 0;
  const estimatedWait = Math.max(0, (position - 1) * 2);

  res.json({
    success: true,
    queue_status: {
      position: position,
      total_in_queue: totalInQueue,
      estimated_wait_minutes: estimatedWait,
      has_pending_uploads: position > 0,
      oldest_upload: queueInfo.oldest_upload
    }
  });
}));

/**
 * Get leaderboard for competitive games
 * GET /api/game/leaderboard
 */
router.get('/leaderboard', requireValidToken, asyncHandler(async (req, res) => {
  const gameId = req.player.game_id;

  try {
    const leaderboard = await getLeaderboard(gameId);

    res.json({
      success: true,
      message: 'Leaderboard retrieved successfully',
      data: {
        game_id: gameId,
        entries: leaderboard,
        updated_at: new Date().toISOString()
      }
    });

  } catch (error) {
    logger.error('Failed to get leaderboard', {
      game_id: gameId,
      error: error.message
    });

    res.status(500).json({
      error: 'Failed to retrieve leaderboard',
      message: error.message
    });
  }
}));

/**
 * Get game configuration
 * GET /api/game/config
 */
router.get('/config', requireValidToken, asyncHandler(async (req, res) => {
  const gameId = req.player.game_id;

  const result = await query(`
    SELECT 
      g.name,
      g.description, 
      g.game_type,
      g.start_audio_path,
      json_object_agg(gc.config_key, gc.config_value) as config
    FROM neoquest.games g
    LEFT JOIN neoquest.game_config gc ON g.id = gc.game_id
    WHERE g.id = $1 AND g.is_active = TRUE
    GROUP BY g.id, g.name, g.description, g.game_type, g.start_audio_path
  `, [gameId]);

  if (result.rows.length === 0) {
    return res.status(404).json({
      error: 'Game not found',
      message: 'Game not found or inactive'
    });
  }

  const gameInfo = result.rows[0];

  res.json({
    success: true,
    game: {
      id: gameId,
      name: gameInfo.name,
      description: gameInfo.description,
      game_type: gameInfo.game_type,
      start_audio_path: gameInfo.start_audio_path,
      config: gameInfo.config || {}
    }
  });
}));

/**
 * Start game session
 * POST /api/game/start
 */
router.post('/start', requireValidToken, asyncHandler(async (req, res) => {
  const playerId = req.player.id;
  const gameId = req.player.game_id;

  await query(`
    UPDATE neoquest.player_games 
    SET started_at = COALESCE(started_at, CURRENT_TIMESTAMP)
    WHERE player_id = $1 AND game_id = $2
  `, [playerId, gameId]);

  logger.info('Game session started', {
    player_id: playerId,
    game_id: gameId,
    player_name: req.player.name
  });

  res.json({
    success: true,
    message: 'Game session started',
    started_at: new Date().toISOString()
  });
}));

/**
 * Get package size info
 * GET /api/game/package-info/:gameId
 */
router.get('/package-info/:gameId', asyncHandler(async (req, res) => {
  try {
    const gameId = parseInt(req.params.gameId);
    
    if (!gameId) {
      return res.status(400).json({
        success: false,
        error: 'Invalid game ID'
      });
    }

    const gameResult = await query(
      'SELECT * FROM neoquest.games WHERE id = $1 AND is_active = true',
      [gameId]
    );

    if (gameResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Game not found'
      });
    }

    const game = gameResult.rows[0];
    
    // Calculate actual package size
    const packageInfo = await calculatePackageSize(gameId, game.name);
    
    res.json({
      success: true,
      package: {
        gameId: gameId,
        gameName: game.name,
        estimatedSize: packageInfo.totalSize,
        estimatedSizeFormatted: formatFileSize(packageInfo.totalSize),
        fileCount: packageInfo.fileCount,
        downloadEstimate: Math.ceil(packageInfo.totalSize / (1024 * 1024))
      }
    });

  } catch (error) {
    logger.error('Error calculating package size:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to calculate package size',
      details: error.message
    });
  }
}));

/**
 * Calculate total package size
 */
async function calculatePackageSize(gameId, gameName) {
  let totalSize = 5120; // 5KB base for JSON data
  let fileCount = 0;

  try {
    // Calculate checkpoints data size
    const checkpointsResult = await query(
      'SELECT COUNT(*) as count FROM neoquest.checkpoints WHERE game_id = $1',
      [gameId]
    );
    const checkpointCount = parseInt(checkpointsResult.rows[0].count) || 0;
    totalSize += checkpointCount * 1024; // 1KB per checkpoint

    // Calculate actual media files
    const gameSlugMapping = {
      1: 'testgame1',
      2: 'testgame2'
    };
    
    const gameSlug = gameSlugMapping[gameId] || gameName.toLowerCase().replace(/\s+/g, '_');
    const mediaPath = path.join(process.cwd(), 'media', 'games', gameSlug);
    
    const directories = ['assets', 'puzzles', 'intro', 'checkpoints'];
    
    for (const dir of directories) {
      const dirPath = path.join(mediaPath, dir);
      const dirSize = await calculateDirectorySize(dirPath);
      totalSize += dirSize.size;
      fileCount += dirSize.fileCount;
    }
    
    return { totalSize, fileCount };

  } catch (error) {
    logger.error('Error calculating package size:', error);
    // Return minimum estimate if calculation fails
    return { totalSize: 1024 * 1024, fileCount: 10 }; // 1MB default
  }
}

/**
 * Calculate directory size recursively
 */
async function calculateDirectorySize(dirPath) {
  let totalSize = 0;
  let fileCount = 0;

  try {
    const items = await fs.readdir(dirPath, { withFileTypes: true });
    
    for (const item of items) {
      const itemPath = path.join(dirPath, item.name);
      
      if (item.isDirectory()) {
        const subDirSize = await calculateDirectorySize(itemPath);
        totalSize += subDirSize.size;
        fileCount += subDirSize.fileCount;
      } else if (item.isFile()) {
        const stats = await fs.stat(itemPath);
        totalSize += stats.size;
        fileCount++;
      }
    }
  } catch (error) {
    // Directory not found - skip silently
  }

  return { size: totalSize, fileCount };
}

/**
 * Format file size in human readable format
 */
function formatFileSize(bytes) {
  if (bytes === 0) return '0 B';
  
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  
  return Math.round((bytes / Math.pow(1024, i)) * 10) / 10 + ' ' + sizes[i];
}

/**
 * Test endpoint
 * GET /api/game/test
 */
router.get('/test', (req, res) => {
  res.json({ 
    message: 'Game routes working!',
    timestamp: new Date().toISOString()
  });
});

module.exports = router;