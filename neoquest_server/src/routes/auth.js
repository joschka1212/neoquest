// neoquest_server/src/routes/auth.js
/**
 * Authentication Routes
 * Handle player registration and token validation
 */

const express = require('express');
const { body, validationResult } = require('express-validator');
const { asyncHandler } = require('../middleware/errorHandler');
const logger = require('../utils/logger');
const { parseQRContent, validateToken } = require('../utils/tokenGenerator');
const { query } = require('../config/database');
const router = express.Router();

/**
 * Register player with QR token
 * POST /api/auth/register
 */
router.post('/register', [
  body('qr_content').isString().trim().isLength({ min: 1 }).withMessage('QR content is required'),
  body('player_info.name').optional().isString().trim().isLength({ min: 1, max: 255 }),
  body('player_info.email').optional().isEmail().normalizeEmail()
], asyncHandler(async (req, res) => {
  // Check validation errors
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }

  const { qr_content, player_info = {} } = req.body;
  
  logger.info('Player registration attempt', { 
    qr_content: qr_content.substring(0, 50) + '...',
    has_name: !!player_info.name,
    has_email: !!player_info.email
  });

  // Parse QR content
  const parsed = parseQRContent(qr_content);
  
  if (!parsed.isValid) {
    logger.warn('Invalid QR code format', { 
      qr_content: qr_content,
      error: parsed.error 
    });
    
    return res.status(400).json({
      error: 'Invalid QR code format',
      details: parsed.error
    });
  }

  // Validate token exists in database
  const validation = await validateToken(parsed.tokenId);
  
  if (!validation.valid) {
    logger.warn('Token validation failed', { 
      token: parsed.tokenId,
      error: validation.error 
    });
    
    return res.status(404).json({
      error: 'Token not found or inactive',
      details: validation.error
    });
  }

  const player = validation.player;

  // Log successful registration
  logger.info('Player registered successfully', {
    player_id: player.id,
    token: player.token,
    game_id: player.game_id,
    game_name: player.game_name
  });

  res.json({
    success: true,
    message: 'Registration successful',
    player: {
      id: player.id,
      token: player.token,
      name: player.name,
      game_id: player.game_id,
      game_name: player.game_name,
      game_title: player.game_title
    }
  });
}));

/**
 * Register player with QR token
 * POST /api/auth/register-with-details
 */
router.post('/register-with-details', async (req, res) => {
  try {
    const { qr_token, player_name, email } = req.body;
    
    // QR-Token validieren
    if (!qr_token.startsWith('NEOQUEST:')) {
      return res.status(400).json({
        success: false,
        error: 'Invalid QR token format'
      });
    }
    
    const parts = qr_token.split(':');
    const tokenId = parts[1]; // ABC123
    const gameTitle = parts[2] || 'Default Game';
    
    // Prüfen ob dieses Token bereits registriert wurde
    const existingPlayer = await query(`
      SELECT id FROM neoquest.players WHERE token = $1
    `, [tokenId]);
    
    if (existingPlayer.rows.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'Token already registered'
      });
    }
    
    // Game ID aus Titel ableiten (oder explizit aus QR)
    let gameId = 1; // Default
    const gameResult = await query(`
      SELECT id FROM neoquest.games WHERE name ILIKE $1 AND is_active = true
    `, [`%${gameTitle}%`]);
    
    if (gameResult.rows.length > 0) {
      gameId = gameResult.rows[0].id;
    }
    
    // Player mit dem gescannten Token erstellen
    const playerResult = await query(`
      INSERT INTO neoquest.players (
        token, name, email, game_id, game_title, 
        qr_code_content, registered_at, is_active
      )
      VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP, true)
      RETURNING id, token, name, email, game_id
    `, [
      tokenId,           // Das gescannte Token (ABC123)
      player_name,
      email || null,
      gameId,
      gameTitle,
      qr_token          // Der komplette QR-Content
    ]);
    
    const player = playerResult.rows[0];
    
    // Player-Game Assignment
    await query(`
      INSERT INTO neoquest.player_games (player_id, game_id, assigned_at)
      VALUES ($1, $2, CURRENT_TIMESTAMP)
    `, [player.id, gameId]);
    
    res.json({
      success: true,
      data: {
        player: {
          id: player.id,
          token: player.token,  // ABC123
          name: player.name,
          email: player.email,
          game_id: player.game_id
        },
        game: {
          id: gameId,
          title: gameTitle
        }
      }
    });
    
  } catch (error) {
    logger.error('Registration failed:', error);
    res.status(500).json({
      success: false,
      error: 'Registration failed'
    });
  }
});

/**
 * Create player account (without token)
 * POST /api/auth/create-player
 */
router.post('/create-player', async (req, res) => {
  try {
    const { player_name, email } = req.body;
    
    if (!player_name || player_name.trim().length < 2) {
      return res.status(400).json({
        success: false,
        error: 'Player name is required (min 2 characters)'
      });
    }
    
    // Temporären Player erstellen (ohne Token/Game)
    const playerResult = await query(`
      INSERT INTO neoquest.players (
        name, email, registered_at, is_active
      )
      VALUES ($1, $2, CURRENT_TIMESTAMP, true)
      RETURNING id, name, email
    `, [
      player_name.trim(),
      email?.trim() || null
    ]);
    
    const player = playerResult.rows[0];
    
    res.json({
      success: true,
      data: {
        player: {
          id: player.id,
          name: player.name,
          email: player.email
        }
      }
    });
    
  } catch (error) {
    logger.error('Player creation failed:', error);
    res.status(500).json({
      success: false,
      error: 'Player creation failed'
    });
  }
});

/**
 * Link token to existing player
 * POST /api/auth/link-token
 */
router.post('/link-token', async (req, res) => {
  try {
    const { player_id, qr_token } = req.body;
    
    if (!qr_token.startsWith('NEOQUEST:')) {
      return res.status(400).json({
        success: false,
        error: 'Invalid QR token format'
      });
    }
    
    const parts = qr_token.split(':');
    const tokenId = parts[1];
    const gameTitle = parts[2] || 'Default Game';
    
    // Prüfen ob Token bereits verwendet
    const existingToken = await query(`
      SELECT id FROM neoquest.players WHERE token = $1
    `, [tokenId]);
    
    if (existingToken.rows.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'Token already used'
      });
    }
    
    // Game ID ermitteln
    let gameId = 1;
    const gameResult = await query(`
      SELECT id FROM neoquest.games WHERE name ILIKE $1 AND is_active = true
    `, [`%${gameTitle}%`]);
    
    if (gameResult.rows.length > 0) {
      gameId = gameResult.rows[0].id;
    }
    
    // Player mit Token und Game verknüpfen
    const playerResult = await query(`
      UPDATE neoquest.players 
      SET token = $1, game_id = $2, game_title = $3, qr_code_content = $4
      WHERE id = $5
      RETURNING id, token, name, email, game_id
    `, [tokenId, gameId, gameTitle, qr_token, player_id]);
    
    const player = playerResult.rows[0];
    
    // Player-Game Assignment
    await query(`
      INSERT INTO neoquest.player_games (player_id, game_id, assigned_at)
      VALUES ($1, $2, CURRENT_TIMESTAMP)
    `, [player.id, gameId]);
    
    res.json({
      success: true,
      data: {
        player: {
          id: player.id,
          token: player.token,
          name: player.name,
          email: player.email,
          game_id: player.game_id
        },
        game: {
          id: gameId,
          title: gameTitle
        }
      }
    });
    
  } catch (error) {
    logger.error('Token linking failed:', error);
    res.status(500).json({
      success: false,
      error: 'Token linking failed'
    });
  }
});

/**
 * Verify token validity
 * POST /api/auth/verify
 */
router.post('/verify', [
  body('token').isString().trim().isLength({ min: 1 }).withMessage('Token is required')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }

  const { token } = req.body;

  const validation = await validateToken(token);

  if (validation.valid) {
    res.json({
      success: true,
      valid: true,
      player: {
        id: validation.player.id,
        token: validation.player.token,
        name: validation.player.name,
        game_id: validation.player.game_id,
        game_name: validation.player.game_name,
        game_completed: validation.player.game_completed
      }
    });
  } else {
    res.status(404).json({
      success: false,
      valid: false,
      error: validation.error
    });
  }
}));

module.exports = router;