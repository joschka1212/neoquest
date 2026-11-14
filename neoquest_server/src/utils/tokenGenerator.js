/**
 * Token Generator Utility
 * Generate QR tokens for NeoQuest players
 */

const crypto = require('crypto');
const { query } = require('../config/database');

/**
 * Generate a unique token ID
 * @returns {string} Unique token ID (e.g., "ABC123")
 */
function generateTokenId() {
  // Generate 6 character alphanumeric token
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  
  return result;
}

/**
 * Generate UUID-based token (alternative)
 * @returns {string} UUID-based token
 */
function generateUuidToken() {
  return crypto.randomUUID().replace(/-/g, '').substring(0, 8).toUpperCase();
}

/**
 * Check if token already exists in database
 * @param {string} token Token to check
 * @returns {Promise<boolean>} True if token exists
 */
async function tokenExists(token) {
  try {
    const result = await query(
      'SELECT id FROM neoquest.players WHERE token = $1',
      [token]
    );
    return result.rows.length > 0;
  } catch (error) {
    console.error('Error checking token existence:', error);
    return false;
  }
}

/**
 * Generate unique token that doesn't exist in database
 * @param {number} maxAttempts Maximum attempts to generate unique token
 * @returns {Promise<string>} Unique token
 */
async function generateUniqueToken(maxAttempts = 10) {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const token = generateTokenId();
    
    if (!(await tokenExists(token))) {
      return token;
    }
  }
  
  // If we can't generate a unique token with simple method, use UUID
  const uuidToken = generateUuidToken();
  
  if (!(await tokenExists(uuidToken))) {
    return uuidToken;
  }
  
  throw new Error('Unable to generate unique token after maximum attempts');
}

/**
 * Get game title by game ID
 * @param {number} gameId Game ID
 * @returns {Promise<string>} Game title
 */
async function getGameTitle(gameId) {
  try {
    const result = await query(
      'SELECT name FROM neoquest.games WHERE id = $1 AND is_active = TRUE',
      [gameId]
    );
    
    if (result.rows.length === 0) {
      throw new Error(`Game with ID ${gameId} not found or inactive`);
    }
    
    return result.rows[0].name;
  } catch (error) {
    console.error('Error fetching game title:', error);
    throw error;
  }
}

/**
 * Generate QR code content
 * @param {string} tokenId Token ID (e.g., "ABC123")
 * @param {string} gameTitle Game title
 * @returns {string} QR code content
 */
function generateQRContent(tokenId, gameTitle) {
  return `NEOQUEST:${tokenId}:${gameTitle}`;
}

/**
 * Parse QR code content
 * @param {string} qrContent QR code content
 * @returns {Object} Parsed content {tokenId, gameTitle}
 */
function parseQRContent(qrContent) {
  try {
    // Expected format: "NEOQUEST:ABC123:Möllersdorf Schatzsuche"
    const parts = qrContent.split(':');
    
    if (parts.length < 3) {
      throw new Error('Invalid QR code format');
    }
    
    if (parts[0] !== 'NEOQUEST') {
      throw new Error('Not a NeoQuest QR code');
    }
    
    const tokenId = parts[1];
    const gameTitle = parts.slice(2).join(':'); // Rejoin in case title contains ':'
    
    return {
      tokenId,
      gameTitle,
      isValid: true
    };
  } catch (error) {
    return {
      tokenId: null,
      gameTitle: null,
      isValid: false,
      error: error.message
    };
  }
}

/**
 * Generate token for a specific game and player
 * @param {number} gameId Game ID
 * @param {string} playerName Player name (optional)
 * @param {string} email Player email (optional)
 * @returns {Promise<Object>} Generated token data
 */
async function generatePlayerToken(gameId, playerName = null, email = null) {
  try {
    // Get game title
    const gameTitle = await getGameTitle(gameId);
    
    // Generate unique token
    const tokenId = await generateUniqueToken();
    
    // Generate QR content
    const qrContent = generateQRContent(tokenId, gameTitle);
    
    // Insert player into database
    const result = await query(`
      INSERT INTO neoquest.players (token, name, email, game_title, qr_code_content)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, token, name, email, game_title, qr_code_content, registered_at
    `, [tokenId, playerName, email, gameTitle, qrContent]);
    
    // Assign player to game
    await query(`
      INSERT INTO neoquest.player_games (player_id, game_id)
      VALUES ($1, $2)
    `, [result.rows[0].id, gameId]);
    
    return {
      success: true,
      player: result.rows[0],
      qrContent: qrContent,
      gameId: gameId
    };
    
  } catch (error) {
    console.error('Error generating player token:', error);
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Generate multiple tokens for a game
 * @param {number} gameId Game ID
 * @param {number} count Number of tokens to generate
 * @param {Array<string>} playerNames Optional array of player names
 * @returns {Promise<Object>} Generated tokens data
 */
async function generateMultipleTokens(gameId, count, playerNames = []) {
  const results = [];
  const errors = [];
  
  try {
    // Validate game exists
    await getGameTitle(gameId);
    
    for (let i = 0; i < count; i++) {
      const playerName = playerNames[i] || null;
      
      try {
        const tokenResult = await generatePlayerToken(gameId, playerName);
        
        if (tokenResult.success) {
          results.push(tokenResult);
        } else {
          errors.push({
            index: i,
            playerName: playerName,
            error: tokenResult.error
          });
        }
      } catch (error) {
        errors.push({
          index: i,
          playerName: playerName,
          error: error.message
        });
      }
    }
    
    return {
      success: true,
      generated: results.length,
      requested: count,
      tokens: results,
      errors: errors
    };
    
  } catch (error) {
    return {
      success: false,
      error: error.message,
      generated: results.length,
      requested: count,
      tokens: results,
      errors: errors
    };
  }
}

/**
 * Validate token and get player data
 * @param {string} token Token to validate
 * @returns {Promise<Object>} Player data if valid
 */
async function validateToken(token) {
  try {
    const result = await query(`
      SELECT p.*, pg.game_id, g.name as game_name
      FROM neoquest.players p
      JOIN neoquest.player_games pg ON p.id = pg.player_id
      JOIN neoquest.games g ON pg.game_id = g.id
      WHERE p.token = $1 AND p.is_active = TRUE AND g.is_active = TRUE
    `, [token]);
    
    if (result.rows.length === 0) {
      return {
        valid: false,
        error: 'Token not found or inactive'
      };
    }
    
    return {
      valid: true,
      player: result.rows[0]
    };
    
  } catch (error) {
    console.error('Error validating token:', error);
    return {
      valid: false,
      error: error.message
    };
  }
}

module.exports = {
  generateTokenId,
  generateUniqueToken,
  generateQRContent,
  parseQRContent,
  generatePlayerToken,
  generateMultipleTokens,
  validateToken,
  getGameTitle
};