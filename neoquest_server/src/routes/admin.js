/**
 * Admin Routes - Erweiterte Version mit Token-Management
 * Administrative endpoints for NeoQuest management
 * 
 * NEUE FEATURES:
 * - Token-Übersicht mit Spieler-Zuordnung
 * - Token freigeben (Player löschen/deaktivieren)  
 * - Bulk Token-Freigabe
 * 
 * 20250801 - Express 5.x compatibility implemented
 * 20250914 - Added comprehensive token management features
 * 
 *  // ===============================================
 *  // NEUE TOKEN-MANAGEMENT FEATURES
 *  // ===============================================

*   GET  /api/admin/tokens-overview
*   GET /api/admin/tokens-of-game/:game_id
*   POST /api/admin/release-token
*   POST /api/admin/release-all-tokens/:game_id
*   POST /api/admin/reactivate-player
*   GET  /api/admin/player-details/:player_id
*   POST /api/admin/reset-player-progress
*   GET  /api/admin/system-health
*
*   POST /api/admin/generate-token
*   POST /api/admin/generate-tokens
*   POST /api/admin/generate-game-tokens
*   GET  /api/admin/players
*   GET  /api/admin/games
*   GET  /api/admin/routes
*   GET  /api/admin/stats
*  POST /api/admin/validate-token
 */

const express = require('express');
const { body, validationResult } = require('express-validator');
const { asyncHandler } = require('../middleware/errorHandler');
const { query } = require('../config/database');
const logger = require('../utils/logger');
const { requireAdmin } = require('../middleware/adminAuth');
const {
  generatePlayerToken,
  generateMultipleTokens,
  validateToken
} = require('../utils/tokenGenerator');

const router = express.Router();

// ===============================================
// NEUE TOKEN-MANAGEMENT FEATURES
// ===============================================

/**
 * GET /api/admin/tokens-overview
 * Token-Übersicht mit Spieler-Zuordnung
 */
router.get('/tokens-overview', requireAdmin, asyncHandler(async (req, res) => {
  const { game_id } = req.query;

  let whereClause = '';
  const params = [];

  if (game_id) {
    whereClause = 'WHERE g.id = $1';
    params.push(game_id);
  }

  logger.info('Token overview requested', { 
    game_id: game_id || 'all_games',
    admin_request: true 
  });

  const result = await query(`
    SELECT 
      g.id as game_id,
      g.name as game_name,
      g.is_active as game_active,
      g.game_type,
      g.complexity_level,
      
      -- Player/Token Information
      p.id as player_id,
      p.token,
      p.name as player_name,
      p.email as player_email,
      p.registered_at,
      p.is_active as player_active,
      p.game_completed,
      p.completion_time,
      p.total_score,
      p.qr_code_content,
      p.mission_completed,
      p.final_mission_score,
      p.mission_completion_timestamp,
      
      -- Token Status
      CASE 
        WHEN p.id IS NULL THEN 'FREE'
        WHEN p.is_active = false THEN 'INACTIVE'
        WHEN p.game_completed = true OR p.mission_completed = true THEN 'COMPLETED'
        ELSE 'ASSIGNED'
      END as token_status,
      
      -- Game Progress
      CASE 
        WHEN p.id IS NULL THEN NULL
        WHEN p.game_completed = true OR p.mission_completed = true THEN '100%'
        WHEN COALESCE(p.total_score, p.final_mission_score, 0) > 0 THEN 
          CONCAT(LEAST(100, ROUND((COALESCE(p.total_score, p.final_mission_score, 0)::decimal / 1000) * 100)), '%')
        ELSE '0%'
      END as game_progress,
      
      -- Last Activity
      GREATEST(p.registered_at, p.mission_completion_timestamp) as last_activity,
      
      -- Additional metrics
      EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - p.registered_at))::INTEGER as days_since_registration

    FROM neoquest.games g
    LEFT JOIN neoquest.players p ON g.id = p.game_id
    ${whereClause}
    ORDER BY g.id, g.name, 
             CASE 
               WHEN p.id IS NULL THEN 0  -- Free tokens first
               WHEN p.is_active = false THEN 1  -- Inactive second
               WHEN p.game_completed = true OR p.mission_completed = true THEN 2  -- Completed third
               ELSE 3  -- Active last
             END,
             p.registered_at DESC
  `, params);

  // Group by game and calculate statistics
  const gameTokens = {};
  let totalTokensCount = 0;
  let freeTokensCount = 0;
  let assignedTokensCount = 0;
  let completedTokensCount = 0;
  let inactiveTokensCount = 0;

  result.rows.forEach(row => {
    const gameId = row.game_id;
    
    if (!gameTokens[gameId]) {
      gameTokens[gameId] = {
        game_id: gameId,
        game_name: row.game_name,
        game_active: row.game_active,
        game_type: row.game_type,
        complexity_level: row.complexity_level,
        tokens: [],
        stats: {
          total: 0,
          free: 0,
          assigned: 0,
          inactive: 0,
          completed: 0
        }
      };
    }

    // Add token if player exists or if we want to show generated tokens
    if (row.token || row.player_id) {
      const tokenData = {
        token: row.token,
        player_id: row.player_id,
        player_name: row.player_name,
        player_email: row.player_email,
        token_status: row.token_status,
        game_progress: row.game_progress,
        registered_at: row.registered_at,
        last_activity: row.last_activity,
        total_score: row.total_score || row.final_mission_score || 0,
        completion_time: row.completion_time,
        qr_code_content: row.qr_code_content,
        days_since_registration: Math.floor(row.days_since_registration / 86400), // Convert to days
        is_mission_completed: row.mission_completed || false
      };

      gameTokens[gameId].tokens.push(tokenData);
      gameTokens[gameId].stats.total++;
      
      // Update statistics
      switch (row.token_status) {
        case 'FREE': 
          gameTokens[gameId].stats.free++;
          freeTokensCount++;
          break;
        case 'ASSIGNED': 
          gameTokens[gameId].stats.assigned++;
          assignedTokensCount++;
          break;
        case 'INACTIVE': 
          gameTokens[gameId].stats.inactive++;
          inactiveTokensCount++;
          break;
        case 'COMPLETED': 
          gameTokens[gameId].stats.completed++;
          completedTokensCount++;
          break;
      }
      totalTokensCount++;
    }
  });

  logger.info('Token overview generated', {
    total_games: Object.keys(gameTokens).length,
    total_tokens: totalTokensCount,
    free_tokens: freeTokensCount,
    assigned_tokens: assignedTokensCount
  });

  res.json({
    success: true,
    message: 'Token overview retrieved successfully',
    overview: {
      total_games: Object.keys(gameTokens).length,
      global_stats: {
        total_tokens: totalTokensCount,
        free_tokens: freeTokensCount,
        assigned_tokens: assignedTokensCount,
        completed_tokens: completedTokensCount,
        inactive_tokens: inactiveTokensCount
      },
      games: Object.values(gameTokens)
    },
    filters_applied: {
      game_id: game_id || null
    },
    generated_at: new Date().toISOString()
  });
}));

/**
 * POST /api/admin/release-token
 * Token freigeben durch Löschen des zugeordneten Players
 * Das Token selbst bleibt bestehen für erneute Anmeldung
 */
router.post('/release-token', [
  body('token').isString().trim().isLength({ min: 1 }).withMessage('Token is required'),
  body('game_id').isInt({ min: 1 }).withMessage('Valid game_id is required'),
  body('reason').optional().isString().trim().isLength({ max: 500 }).withMessage('Reason too long')
], requireAdmin, asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      details: errors.array()
    });
  }

  const { token, game_id, reason = '' } = req.body;

  logger.info('Token release request (player deletion only)', {
    token: token,
    game_id: game_id,
    reason: reason,
    admin_action: true
  });

  // Check if token exists and is assigned to a player
  const playerResult = await query(`
    SELECT 
      p.id, 
      p.name, 
      p.email, 
      p.token, 
      p.game_id,
      p.is_active,
      p.game_completed,
      p.mission_completed,
      p.total_score,
      p.final_mission_score,
      p.registered_at,
      g.name as game_name
    FROM neoquest.players p
    JOIN neoquest.games g ON p.game_id = g.id
    WHERE p.token = $1 AND p.game_id = $2
  `, [token, game_id]);

  if (playerResult.rows.length === 0) {
    logger.warn('Token release failed - token not assigned', {
      token: token,
      game_id: game_id
    });
    
    return res.status(404).json({
      success: false,
      error: 'Token not assigned to any player',
      details: `Token "${token}" is currently free in game ${game_id}`,
      token_status: 'already_free'
    });
  }

  const player = playerResult.rows[0];
  
  try {
    // ONLY DELETE THE PLAYER - Token stays in system for re-registration
    await query('BEGIN');
    
    const deleteResult = await query(`
      DELETE FROM neoquest.players 
      WHERE id = $1 
      RETURNING id, name, token
    `, [player.id]);

    await query('COMMIT');

    logger.info('Player deleted - token released for re-registration', {
      player_id: player.id,
      token: token,
      player_name: player.name,
      game_id: game_id,
      admin_reason: reason,
      token_preserved: true
    });

    res.json({
      success: true,
      message: 'Token released - Player deleted, token available for new registration',
      released_token: {
        token: token,
        game_id: game_id,
        game_name: player.game_name,
        token_status: 'free_for_registration',
        former_player: {
          id: player.id,
          name: player.name,
          email: player.email,
          was_completed: player.game_completed || player.mission_completed,
          total_score: player.total_score || player.final_mission_score || 0,
          registered_at: player.registered_at
        },
        release_details: {
          player_deleted: true,
          token_preserved: true,
          can_register_again: true,
          admin_reason: reason,
          released_at: new Date().toISOString()
        }
      }
    });

  } catch (error) {
    await query('ROLLBACK');
    logger.error('Token release failed', {
      token: token,
      error: error.message,
      player_id: player.id
    });

    res.status(500).json({
      success: false,
      error: 'Failed to release token',
      details: error.message
    });
  }
}));

/**
 * POST /api/admin/release-all-tokens/:game_id
 * Gibt alle Tokens eines Spiels frei (löscht alle Player des Spiels)
 */
router.post('/release-all-tokens/:game_id', [
  body('reason').optional().isString().trim().isLength({ max: 500 }).withMessage('Reason too long'),
  body('confirm').isBoolean().withMessage('Confirmation required')
], requireAdmin, asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      details: errors.array()
    });
  }

  const { game_id } = req.params;
  const { reason = '', confirm } = req.body;

  if (!game_id || isNaN(game_id)) {
    return res.status(400).json({
      success: false,
      error: 'Invalid game_id'
    });
  }

  if (!confirm) {
    return res.status(400).json({
      success: false,
      error: 'Confirmation required',
      details: 'Set "confirm": true to proceed with releasing all tokens'
    });
  }

  logger.info('Release-all-tokens request', {
    game_id: game_id,
    reason: reason,
    admin_action: true
  });

  // Get game info and count assigned players
  const gameInfoResult = await query(`
    SELECT 
      g.id,
      g.name as game_name,
      g.is_active,
      COUNT(p.id) as assigned_players,
      COUNT(CASE WHEN p.game_completed = true OR p.mission_completed = true THEN 1 END) as completed_players,
      COUNT(CASE WHEN p.is_active = false THEN 1 END) as inactive_players
    FROM neoquest.games g
    LEFT JOIN neoquest.players p ON g.id = p.game_id
    WHERE g.id = $1
    GROUP BY g.id, g.name, g.is_active
  `, [game_id]);

  if (gameInfoResult.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Game not found',
      details: `Game with ID ${game_id} not found`
    });
  }

  const gameInfo = gameInfoResult.rows[0];
  const assignedPlayers = parseInt(gameInfo.assigned_players) || 0;

  if (assignedPlayers === 0) {
    return res.json({
      success: true,
      message: 'No tokens to release - all tokens already free',
      game: {
        id: gameInfo.id,
        name: gameInfo.game_name,
        assigned_players: 0
      },
      tokens_released: 0
    });
  }

  // Get detailed player info before deletion
  const playersResult = await query(`
    SELECT 
      id, token, name, email, 
      game_completed, mission_completed,
      total_score, final_mission_score,
      registered_at, is_active
    FROM neoquest.players 
    WHERE game_id = $1
    ORDER BY registered_at DESC
  `, [game_id]);

  try {
    await query('BEGIN');
    
    // Delete all players for this game (CASCADE will handle dependent data)
    const deleteResult = await query(`
      DELETE FROM neoquest.players 
      WHERE game_id = $1 
      RETURNING id, token, name
    `, [game_id]);

    await query('COMMIT');

    const deletedCount = deleteResult.rowCount;
    const deletedPlayers = playersResult.rows;

    logger.info('All tokens released for game', {
      game_id: game_id,
      game_name: gameInfo.game_name,
      players_deleted: deletedCount,
      completed_players: gameInfo.completed_players,
      admin_reason: reason
    });

    res.json({
      success: true,
      message: `All tokens released for game "${gameInfo.game_name}" - ${deletedCount} players deleted`,
      game: {
        id: gameInfo.id,
        name: gameInfo.game_name,
        was_active: gameInfo.is_active
      },
      release_summary: {
        tokens_released: deletedCount,
        players_deleted: deletedCount,
        completed_players_deleted: parseInt(gameInfo.completed_players) || 0,
        inactive_players_deleted: parseInt(gameInfo.inactive_players) || 0
      },
      deleted_players: deletedPlayers.map(player => ({
        token: player.token,
        name: player.name,
        email: player.email,
        was_completed: player.game_completed || player.mission_completed,
        score: player.total_score || player.final_mission_score || 0,
        registered_at: player.registered_at,
        was_active: player.is_active
      })),
      operation_details: {
        all_tokens_now_free: true,
        players_can_reregister: true,
        admin_reason: reason,
        processed_at: new Date().toISOString()
      }
    });

  } catch (error) {
    await query('ROLLBACK');
    logger.error('Release-all-tokens failed', {
      game_id: game_id,
      error: error.message
    });

    res.status(500).json({
      success: false,
      error: 'Failed to release all tokens',
      details: error.message
    });
  }
}));

/**
 * GET /api/admin/tokens-of-game/:game_id
 * Kompakte Token-Liste für ein bestimmtes Spiel
 */
router.get('/tokens-of-game/:game_id', requireAdmin, asyncHandler(async (req, res) => {
  const { game_id } = req.params;

  if (!game_id || isNaN(game_id)) {
    return res.status(400).json({
      success: false,
      error: 'Invalid game_id'
    });
  }

  logger.info('Tokens-of-game requested', { 
    game_id: game_id,
    admin_request: true 
  });

  // Get game info and all tokens for this game
  const result = await query(`
    SELECT 
      g.id as game_id,
      g.name as game_name,
      g.is_active as game_active,
      
      -- Token/Player Information
      p.id as player_id,
      p.token,
      p.name as player_name,
      p.is_active as player_active,
      p.game_completed,
      p.mission_completed,
      
      -- Token Status
      CASE 
        WHEN p.id IS NULL THEN 'not assigned'
        WHEN p.is_active = false THEN 'inactive'
        WHEN p.game_completed = true OR p.mission_completed = true THEN 'completed'
        ELSE p.name
      END as token_status,
      
      p.registered_at

    FROM neoquest.games g
    LEFT JOIN neoquest.players p ON g.id = p.game_id
    WHERE g.id = $1
    ORDER BY p.registered_at ASC, p.token ASC
  `, [game_id]);

  if (result.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Game not found',
      details: `Game with ID ${game_id} not found`
    });
  }

  // Extract game info from first row
  const gameInfo = {
    id: result.rows[0].game_id,
    name: result.rows[0].game_name,
    is_active: result.rows[0].game_active
  };

  // Build token list
  const tokens = [];
  const tokenStats = {
    total: 0,
    not_assigned: 0,
    assigned: 0,
    completed: 0,
    inactive: 0
  };

  result.rows.forEach(row => {
    if (row.token) { // Only include rows that have tokens
      tokens.push({
        token: row.token,
        player_name: row.player_name,
        token_status: row.token_status,
        player_id: row.player_id,
        registered_at: row.registered_at
      });

      tokenStats.total++;

      // Count by status
      if (row.token_status === 'not assigned') {
        tokenStats.not_assigned++;
      } else if (row.token_status === 'inactive') {
        tokenStats.inactive++;
      } else if (row.token_status === 'completed') {
        tokenStats.completed++;
      } else {
        tokenStats.assigned++;
      }
    }
  });

  // Build response in requested format
  const response = {
    success: true,
    game: gameInfo,
    message: `Game ${gameInfo.name} contains ${tokenStats.total} tokens:`,
    tokens: tokens.map((token, index) => ({
      number: index + 1,
      token: token.token,
      status: token.token_status,
      player_id: token.player_id,
      registered_at: token.registered_at
    })),
    statistics: tokenStats,
    generated_at: new Date().toISOString()
  };

  // Create simple text format for easy reading
  let simpleFormat = `Game ${gameInfo.name} contains ${tokenStats.total} tokens:\n`;
  tokens.forEach((token, index) => {
    simpleFormat += `${index + 1}: ${token.token} ${token.token_status}\n`;
  });

  response.simple_format = simpleFormat;

  logger.info('Tokens-of-game generated', {
    game_id: game_id,
    game_name: gameInfo.name,
    total_tokens: tokenStats.total,
    not_assigned: tokenStats.not_assigned
  });

  res.json(response);
}));

// ===============================================
// BESTEHENDE ADMIN FEATURES (BEIBEHALTEN)
// ===============================================

/**
 * Generate single token for a player
 * POST /api/admin/generate-token
 */
router.post('/generate-token', [
  body('game_id').isInt({ min: 1 }).withMessage('Valid game_id is required'),
  body('player_name').optional().isString().trim().isLength({ min: 1, max: 255 }),
  body('email').optional().isEmail().normalizeEmail()
], requireAdmin, asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }

  const { game_id, player_name, email } = req.body;

  logger.info('Generating single token', { game_id, player_name, email });

  const result = await generatePlayerToken(game_id, player_name, email);

  if (result.success) {
    logger.info('Token generated successfully', { 
      token: result.player.token,
      game_id: game_id 
    });

    res.json({
      success: true,
      message: 'Token generated successfully',
      data: {
        player_id: result.player.id,
        token: result.player.token,
        qr_content: result.qrContent,
        player_name: result.player.name,
        game_title: result.player.game_title,
        registered_at: result.player.registered_at
      }
    });
  } else {
    logger.error('Token generation failed', { error: result.error });
    res.status(500).json({
      success: false,
      error: result.error
    });
  }
}));

/**
 * Generate multiple tokens for a game
 * POST /api/admin/generate-tokens
 */
router.post('/generate-tokens', [
  body('game_id').isInt({ min: 1 }).withMessage('Valid game_id is required'),
  body('count').isInt({ min: 1, max: 100 }).withMessage('Count must be between 1 and 100'),
  body('player_names').optional().isArray().withMessage('player_names must be an array'),
  body('player_names.*').optional().isString().trim().isLength({ min: 1, max: 255 })
], requireAdmin, asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }

  const { game_id, count, player_names = [] } = req.body;

  logger.info('Generating multiple tokens', { 
    game_id, 
    count, 
    named_players: player_names.length 
  });

  const result = await generateMultipleTokens(game_id, count, player_names);

  if (result.success) {
    logger.info('Tokens generated', { 
      generated: result.generated,
      requested: result.requested,
      errors: result.errors.length
    });

    res.json({
      success: true,
      message: `Generated ${result.generated} of ${result.requested} tokens`,
      data: {
        generated_count: result.generated,
        requested_count: result.requested,
        tokens: result.tokens.map(token => ({
          player_id: token.player.id,
          token: token.player.token,
          qr_content: token.qrContent,
          player_name: token.player.name,
          game_title: token.player.game_title
        })),
        errors: result.errors
      }
    });
  } else {
    logger.error('Token generation failed', { error: result.error });
    res.status(500).json({
      success: false,
      error: result.error,
      data: {
        generated_count: result.generated,
        requested_count: result.requested,
        errors: result.errors
      }
    });
  }
}));

/**
 * Token generation for games
 * POST /api/admin/generate-game-tokens
 */
router.post('/generate-game-tokens', requireAdmin, async (req, res) => {
  try {
    const { game_id, count = 1, prefix = '' } = req.body;
    
    // Validate game
    const gameResult = await query(`
      SELECT id, name FROM neoquest.games WHERE id = $1 AND is_active = true
    `, [game_id]);
    
    if (gameResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Game not found'
      });
    }
    
    const game = gameResult.rows[0];
    const tokens = [];
    
    for (let i = 0; i < count; i++) {
      // Generate token (e.g. ABC123, DEF456, etc.)
      const tokenId = prefix + Math.random().toString(36).substr(2, 6).toUpperCase();
      const qrContent = `NEOQUEST:${tokenId}:${game.name}`;
      
      tokens.push({
        token_id: tokenId,
        qr_content: qrContent,
        game_id: game.id,
        game_name: game.name
      });
    }
    
    res.json({
      success: true,
      data: {
        tokens: tokens,
        game: game
      }
    });
    
  } catch (error) {
    logger.error('Token generation failed:', error);
    res.status(500).json({
      success: false,
      error: 'Token generation failed'
    });
  }
});

/**
 * Get all players and their tokens
 * GET /api/admin/players
 */
router.get('/players', requireAdmin, asyncHandler(async (req, res) => {
  const { game_id } = req.query;

  let queryText = `
    SELECT 
      p.id,
      p.token,
      p.name,
      p.email,
      p.game_title,
      p.qr_code_content,
      p.registered_at,
      p.is_active,
      p.game_completed,
      p.completion_time,
      p.total_score,
      p.mission_completed,
      p.final_mission_score,
      p.mission_completion_timestamp,
      pg.game_id,
      pg.started_at,
      pg.completed_at,
      g.name as game_name
    FROM neoquest.players p
    LEFT JOIN neoquest.player_games pg ON p.id = pg.player_id
    LEFT JOIN neoquest.games g ON pg.game_id = g.id
  `;

  const params = [];

  if (game_id) {
    queryText += ' WHERE pg.game_id = $1';
    params.push(game_id);
  }

  queryText += ' ORDER BY p.registered_at DESC';

  const result = await query(queryText, params);

  res.json({
    success: true,
    count: result.rows.length,
    players: result.rows
  });
}));

/**
 * Get all games available for token generation
 * GET /api/admin/games
 */
router.get('/games', requireAdmin, asyncHandler(async (req, res) => {
  const result = await query(`
    SELECT 
      g.id,
      g.name,
      g.description,
      g.created_at,
      g.is_active,
      COUNT(pg.player_id) as player_count,
      COUNT(CASE WHEN p.game_completed = true OR p.mission_completed = true THEN 1 END) as completed_count
    FROM neoquest.games g
    LEFT JOIN neoquest.player_games pg ON g.id = pg.game_id
    LEFT JOIN neoquest.players p ON pg.player_id = p.id
    GROUP BY g.id, g.name, g.description, g.created_at, g.is_active
    ORDER BY g.created_at DESC
  `);

  res.json({
    success: true,
    count: result.rows.length,
    games: result.rows
  });
}));

/**
 * Get player routes/tracking data
 * GET /api/admin/routes
 */
router.get('/routes', requireAdmin, asyncHandler(async (req, res) => {
  const { game_id, player_id } = req.query;

  let whereConditions = [];
  const params = [];

  if (game_id) {
    whereConditions.push('gt.game_id = $' + (params.length + 1));
    params.push(game_id);
  }

  if (player_id) {
    whereConditions.push('p.id = $' + (params.length + 1));
    params.push(player_id);
  }

  const whereClause = whereConditions.length > 0 ? 
    'WHERE ' + whereConditions.join(' AND ') : '';

  const routesQuery = `
    SELECT 
      p.id as player_id,
      p.name as player_name,
      p.token,
      p.game_completed,
      p.mission_completed,
      p.completion_time,
      p.total_score,
      p.final_mission_score,
      g.name as game_name,
      json_agg(
        json_build_object(
          'lat', gt.latitude,
          'lng', gt.longitude,
          'timestamp', gt.timestamp,
          'accuracy', gt.accuracy,
          'altitude', gt.altitude
        ) ORDER BY gt.timestamp
      ) as route
    FROM neoquest.players p
    LEFT JOIN neoquest.gps_tracks gt ON p.id = gt.player_id
    LEFT JOIN neoquest.games g ON gt.game_id = g.id
    ${whereClause}
    GROUP BY p.id, p.name, p.token, p.game_completed, p.mission_completed, p.completion_time, p.total_score, p.final_mission_score, g.name
    ORDER BY p.name
  `;

  const result = await query(routesQuery, params);

  res.json({
    success: true,
    count: result.rows.length,
    routes: result.rows
  });
}));

/**
 * Get game statistics
 * GET /api/admin/stats
 */
router.get('/stats', requireAdmin, asyncHandler(async (req, res) => {
  // Get overall stats
  const overallStats = await query(`
    SELECT 
      COUNT(DISTINCT p.id) as total_players,
      COUNT(DISTINCT g.id) as total_games,
      COUNT(CASE WHEN p.game_completed = true OR p.mission_completed = true THEN 1 END) as completed_games,
      COUNT(CASE WHEN p.is_active = true THEN 1 END) as active_players,
      ROUND(AVG(p.completion_time)) as avg_completion_time,
      ROUND(AVG(COALESCE(p.total_score, p.final_mission_score, 0))) as avg_score
    FROM neoquest.players p
    LEFT JOIN neoquest.player_games pg ON p.id = pg.player_id
    LEFT JOIN neoquest.games g ON pg.game_id = g.id
  `);

  // Get stats per game
  const gameStats = await query(`
    SELECT 
      g.id,
      g.name as game_name,
      COUNT(pg.player_id) as player_count,
      COUNT(CASE WHEN p.game_completed = true OR p.mission_completed = true THEN 1 END) as completed_count,
      ROUND(AVG(p.completion_time)) as avg_completion_time,
      ROUND(AVG(COALESCE(p.total_score, p.final_mission_score, 0))) as avg_score,
      MIN(p.completion_time) as best_time,
      MAX(COALESCE(p.total_score, p.final_mission_score, 0)) as best_score
    FROM neoquest.games g
    LEFT JOIN neoquest.player_games pg ON g.id = pg.game_id
    LEFT JOIN neoquest.players p ON pg.player_id = p.id
    GROUP BY g.id, g.name
    ORDER BY g.name
  `);

  res.json({
    success: true,
    overall: overallStats.rows[0],
    games: gameStats.rows
  });
}));

/**
 * Validate a token (for testing)
 * POST /api/admin/validate-token
 */
router.post('/validate-token', [
  body('token').isString().trim().isLength({ min: 1 }).withMessage('Token is required')
], requireAdmin, asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }

  const { token } = req.body;

  const result = await validateToken(token);

  if (result.valid) {
    res.json({
      success: true,
      valid: true,
      player: result.player
    });
  } else {
    res.status(404).json({
      success: false,
      valid: false,
      error: result.error
    });
  }
}));

// ===============================================
// ZUSÄTZLICHE ADMIN-HILFSFUNKTIONEN
// ===============================================

/**
 * POST /api/admin/reactivate-player
 * Reaktiviert einen deaktivierten Spieler
 */
router.post('/reactivate-player', [
  body('player_id').isInt({ min: 1 }).withMessage('Valid player_id is required'),
  body('reason').optional().isString().trim().isLength({ max: 500 })
], requireAdmin, asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      details: errors.array()
    });
  }

  const { player_id, reason = '' } = req.body;

  // Check if player exists and is inactive
  const playerResult = await query(`
    SELECT 
      p.id, p.name, p.token, p.is_active, p.game_id,
      g.name as game_name
    FROM neoquest.players p
    JOIN neoquest.games g ON p.game_id = g.id
    WHERE p.id = $1
  `, [player_id]);

  if (playerResult.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Player not found'
    });
  }

  const player = playerResult.rows[0];

  if (player.is_active) {
    return res.status(400).json({
      success: false,
      error: 'Player is already active',
      details: `Player "${player.name}" is already active`
    });
  }

  try {
    const reactivateResult = await query(`
      UPDATE neoquest.players 
      SET 
        is_active = true,
        player_config = COALESCE(player_config, '{}')::jsonb || $2::jsonb
      WHERE id = $1 
      RETURNING id, name, token, is_active
    `, [player_id, JSON.stringify({
      reactivated_at: new Date().toISOString(),
      reactivated_reason: reason,
      reactivated_by: 'admin'
    })]);

    logger.info('Player reactivated', {
      player_id: player.id,
      player_name: player.name,
      token: player.token,
      game_id: player.game_id,
      admin_reason: reason
    });

    res.json({
      success: true,
      message: 'Player reactivated successfully',
      reactivated_player: {
        id: player.id,
        name: player.name,
        token: player.token,
        game_id: player.game_id,
        game_name: player.game_name,
        is_active: true,
        reactivation_details: {
          reason: reason,
          reactivated_at: new Date().toISOString()
        }
      }
    });

  } catch (error) {
    logger.error('Player reactivation failed', {
      player_id: player_id,
      error: error.message
    });

    res.status(500).json({
      success: false,
      error: 'Failed to reactivate player',
      details: error.message
    });
  }
}));

/**
 * GET /api/admin/player-details/:player_id
 * Detaillierte Informationen über einen Spieler
 */
router.get('/player-details/:player_id', requireAdmin, asyncHandler(async (req, res) => {
  const { player_id } = req.params;

  if (!player_id || isNaN(player_id)) {
    return res.status(400).json({
      success: false,
      error: 'Invalid player_id'
    });
  }

  // Get comprehensive player information
  const playerResult = await query(`
    SELECT 
      p.*,
      g.name as game_name,
      g.game_type,
      g.complexity_level,
      
      -- Count related data
      COUNT(DISTINCT gs.id) as session_count,
      COUNT(DISTINCT gt.id) as gps_points_count,
      COUNT(DISTINCT mu.id) as upload_count,
      
      -- Latest activity
      MAX(gs.updated_at) as last_session_activity,
      MAX(gt.timestamp) as last_gps_point,
      MAX(mu.uploaded_at) as last_upload
      
    FROM neoquest.players p
    LEFT JOIN neoquest.games g ON p.game_id = g.id
    LEFT JOIN neoquest.game_sessions gs ON p.id = gs.player_id
    LEFT JOIN neoquest.gps_tracks gt ON gs.id = gt.session_id
    LEFT JOIN neoquest.mission_uploads mu ON p.id = mu.player_id
    WHERE p.id = $1
    GROUP BY p.id, g.name, g.game_type, g.complexity_level
  `, [player_id]);

  if (playerResult.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Player not found'
    });
  }

  const player = playerResult.rows[0];

  // Get recent sessions
  const sessionsResult = await query(`
    SELECT 
      id, session_token, start_time, end_time, 
      session_status, final_score, created_at
    FROM neoquest.game_sessions 
    WHERE player_id = $1 
    ORDER BY created_at DESC 
    LIMIT 10
  `, [player_id]);

  // Get recent uploads
  const uploadsResult = await query(`
    SELECT 
      id, upload_type, upload_status, file_size,
      uploaded_at, created_at
    FROM neoquest.mission_uploads 
    WHERE player_id = $1 
    ORDER BY created_at DESC 
    LIMIT 10
  `, [player_id]);

  res.json({
    success: true,
    player_details: {
      basic_info: {
        id: player.id,
        name: player.name,
        email: player.email,
        token: player.token,
        qr_code_content: player.qr_code_content,
        registered_at: player.registered_at,
        is_active: player.is_active
      },
      game_info: {
        game_id: player.game_id,
        game_name: player.game_name,
        game_type: player.game_type,
        complexity_level: player.complexity_level,
        game_title: player.game_title
      },
      progress: {
        game_completed: player.game_completed || false,
        mission_completed: player.mission_completed || false,
        total_score: player.total_score || 0,
        final_mission_score: player.final_mission_score || 0,
        completion_time: player.completion_time,
        mission_completion_timestamp: player.mission_completion_timestamp,
        mission_upload_status: player.mission_upload_status || 'pending'
      },
      activity_stats: {
        session_count: parseInt(player.session_count) || 0,
        gps_points_count: parseInt(player.gps_points_count) || 0,
        upload_count: parseInt(player.upload_count) || 0,
        last_session_activity: player.last_session_activity,
        last_gps_point: player.last_gps_point,
        last_upload: player.last_upload
      },
      recent_sessions: sessionsResult.rows,
      recent_uploads: uploadsResult.rows,
      player_config: player.player_config || {}
    },
    generated_at: new Date().toISOString()
  });
}));

/**
 * POST /api/admin/reset-player-progress  
 * Setzt den Fortschritt eines Spielers zurück
 */
router.post('/reset-player-progress', [
  body('player_id').isInt({ min: 1 }).withMessage('Valid player_id is required'),
  body('reset_type').isIn(['soft', 'hard']).withMessage('Reset type must be "soft" or "hard"'),
  body('reason').optional().isString().trim().isLength({ max: 500 })
], requireAdmin, asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      details: errors.array()
    });
  }

  const { player_id, reset_type, reason = '' } = req.body;

  // Check if player exists
  const playerResult = await query(`
    SELECT id, name, token, game_id, total_score, game_completed
    FROM neoquest.players 
    WHERE id = $1
  `, [player_id]);

  if (playerResult.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Player not found'
    });
  }

  const player = playerResult.rows[0];

  try {
    await query('BEGIN');

    if (reset_type === 'soft') {
      // Soft reset: Only reset scores and completion status
      await query(`
        UPDATE neoquest.players 
        SET 
          game_completed = false,
          mission_completed = false,
          total_score = 0,
          final_mission_score = 0,
          completion_time = NULL,
          mission_completion_timestamp = NULL,
          mission_upload_status = 'pending',
          player_config = COALESCE(player_config, '{}')::jsonb || $2::jsonb
        WHERE id = $1
      `, [player_id, JSON.stringify({
        reset_at: new Date().toISOString(),
        reset_type: 'soft',
        reset_reason: reason,
        reset_by: 'admin',
        previous_score: player.total_score
      })]);

    } else if (reset_type === 'hard') {
      // Hard reset: Delete all associated data
      await query(`DELETE FROM neoquest.gps_tracks WHERE session_id IN (
        SELECT id FROM neoquest.game_sessions WHERE player_id = $1
      )`, [player_id]);
      
      await query(`DELETE FROM neoquest.game_sessions WHERE player_id = $1`, [player_id]);
      await query(`DELETE FROM neoquest.mission_uploads WHERE player_id = $1`, [player_id]);
      
      // Reset player data
      await query(`
        UPDATE neoquest.players 
        SET 
          game_completed = false,
          mission_completed = false,
          total_score = 0,
          final_mission_score = 0,
          completion_time = NULL,
          mission_completion_timestamp = NULL,
          mission_upload_status = 'pending',
          player_config = $2::jsonb
        WHERE id = $1
      `, [player_id, JSON.stringify({
        reset_at: new Date().toISOString(),
        reset_type: 'hard',
        reset_reason: reason,
        reset_by: 'admin',
        previous_score: player.total_score,
        all_data_deleted: true
      })]);
    }

    await query('COMMIT');

    logger.info('Player progress reset', {
      player_id: player.id,
      player_name: player.name,
      reset_type: reset_type,
      previous_score: player.total_score,
      admin_reason: reason
    });

    res.json({
      success: true,
      message: `Player progress ${reset_type} reset completed`,
      reset_details: {
        player_id: player.id,
        player_name: player.name,
        token: player.token,
        reset_type: reset_type,
        previous_score: player.total_score,
        was_completed: player.game_completed,
        reset_reason: reason,
        reset_at: new Date().toISOString()
      }
    });

  } catch (error) {
    await query('ROLLBACK');
    logger.error('Player progress reset failed', {
      player_id: player_id,
      reset_type: reset_type,
      error: error.message
    });

    res.status(500).json({
      success: false,
      error: 'Failed to reset player progress',
      details: error.message
    });
  }
}));

/**
 * GET /api/admin/system-health
 * System Health Check für Admin Dashboard
 */
router.get('/system-health', requireAdmin, asyncHandler(async (req, res) => {
  try {
    // Database health check
    const dbHealthResult = await query(`
      SELECT 
        COUNT(DISTINCT p.id) as total_players,
        COUNT(DISTINCT g.id) as total_games,
        COUNT(DISTINCT gs.id) as total_sessions,
        COUNT(*) FILTER (WHERE p.is_active = true) as active_players,
        COUNT(*) FILTER (WHERE p.game_completed = true OR p.mission_completed = true) as completed_players,
        COUNT(*) FILTER (WHERE gs.session_status = 'started') as active_sessions
      FROM neoquest.players p
      CROSS JOIN neoquest.games g
      LEFT JOIN neoquest.game_sessions gs ON p.id = gs.player_id
    `);

    // Upload queue health
    const uploadQueueResult = await query(`
      SELECT 
        COUNT(*) as total_uploads,
        COUNT(*) FILTER (WHERE upload_status = 'pending') as pending_uploads,
        COUNT(*) FILTER (WHERE upload_status = 'failed') as failed_uploads
      FROM neoquest.mission_uploads
      WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '24 hours'
    `);

    const health = dbHealthResult.rows[0];
    const uploads = uploadQueueResult.rows[0];

    const healthStatus = {
      database: 'healthy',
      players: {
        total: parseInt(health.total_players) || 0,
        active: parseInt(health.active_players) || 0,
        completed: parseInt(health.completed_players) || 0
      },
      games: {
        total: parseInt(health.total_games) || 0,
        active_sessions: parseInt(health.active_sessions) || 0
      },
      uploads_24h: {
        total: parseInt(uploads.total_uploads) || 0,
        pending: parseInt(uploads.pending_uploads) || 0,
        failed: parseInt(uploads.failed_uploads) || 0
      },
      server: {
        uptime_seconds: Math.floor(process.uptime()),
        memory_usage: process.memoryUsage(),
        node_version: process.version
      },
      status: 'healthy',
      checked_at: new Date().toISOString()
    };

    // Determine overall health status
    if (uploads.failed_uploads > 10 || uploads.pending_uploads > 50) {
      healthStatus.status = 'warning';
    }

    if (health.active_sessions > 100) {
      healthStatus.status = 'high_load';
    }

    res.json({
      success: true,
      health: healthStatus
    });

  } catch (error) {
    logger.error('System health check failed', { error: error.message });

    res.json({
      success: true,
      health: {
        status: 'unhealthy',
        database: 'error',
        error: error.message,
        checked_at: new Date().toISOString()
      }
    });
  }
}));

module.exports = router;