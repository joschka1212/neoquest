// neoquest_server/src/services/gameDataService.js

/**
 * Game Data Service
 * Handles game data preparation for different game modes
 */

const { query } = require('../config/database');
const logger = require('../utils/logger');

/**
 * Get complete game data for a player
 * @param {number} playerId Player ID
 * @param {string} gameMode Game mode override (optional)
 * @returns {Promise<Object>} Complete game data package
 */
async function getGameDataForPlayer(playerId, gameMode = null) {
  try {
    // Get player and game information
    const playerData = await getPlayerGameInfo(playerId);
    
    if (!playerData) {
      throw new Error('Player not found or not assigned to a game');
    }

    // Use override mode or game's default mode
    const effectiveMode = gameMode || playerData.game_type || 'competitive';
    
    logger.info('Preparing game data', {
      player_id: playerId,
      game_id: playerData.game_id,
      game_mode: effectiveMode,
      game_name: playerData.game_name
    });

    // Get base game data
    const gameData = await getBaseGameData(playerData.game_id);
    
    // Apply mode-specific modifications
    let finalGameData;
    
    switch (effectiveMode) {
      case 'individual':
        finalGameData = await prepareIndividualGameData(gameData, playerId);
        break;
      case 'competitive':
        finalGameData = await prepareCompetitiveGameData(gameData, playerId);
        break;
      case 'team':
        finalGameData = await prepareTeamGameData(gameData, playerId);
        break;
      case 'tutorial':
        finalGameData = await prepareTutorialGameData(gameData, playerId);
        break;
      default:
        finalGameData = await prepareCompetitiveGameData(gameData, playerId);
    }

    // Add metadata
    finalGameData.metadata = {
      game_mode: effectiveMode,
      player_id: playerId,
      game_id: playerData.game_id,
      generated_at: new Date().toISOString(),
      version: '1.0.0'
    };

    return finalGameData;

  } catch (error) {
    logger.error('Error preparing game data', {
      player_id: playerId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Get player and game information
 * @param {number} playerId Player ID
 * @returns {Promise<Object>} Player game info
 */
async function getPlayerGameInfo(playerId) {
  const result = await query(`
    SELECT 
      p.id as player_id,
      p.token,
      p.name as player_name,
      p.game_title,
      pg.game_id,
      g.name as game_name,
      g.description as game_description,
      g.start_audio_path,
      g.game_type,
      g.is_active
    FROM neoquest.players p
    JOIN neoquest.player_games pg ON p.id = pg.player_id
    JOIN neoquest.games g ON pg.game_id = g.id
    WHERE p.id = $1 AND p.is_active = TRUE AND g.is_active = TRUE
  `, [playerId]);

  return result.rows.length > 0 ? result.rows[0] : null;
}

/**
 * Get base game data (checkpoints, puzzles, config)
 * @param {number} gameId Game ID
 * @returns {Promise<Object>} Base game data
 */
async function getBaseGameData(gameId) {
  // Get checkpoints
  const checkpointsResult = await query(`
    SELECT 
      id,
      name,
      latitude,
      longitude,
      radius,
      qr_code,
      checkpoint_type,
      order_index,
      description
    FROM neoquest.checkpoints
    WHERE game_id = $1
    ORDER BY order_index
  `, [gameId]);

  // Get puzzles
  const puzzlesResult = await query(`
    SELECT 
      id,
      title,
      question,
      answer,
      media_path,
      points,
      order_index
    FROM neoquest.puzzles
    WHERE game_id = $1
    ORDER BY order_index
  `, [gameId]);

  // Get game configuration
  const configResult = await query(`
    SELECT config_key, config_value
    FROM neoquest.game_config
    WHERE game_id = $1
  `, [gameId]);

  // Convert config to object
  const config = {};
  configResult.rows.forEach(row => {
    config[row.config_key] = row.config_value;
  });

  return {
    checkpoints: checkpointsResult.rows,
    puzzles: puzzlesResult.rows,
    config: config
  };
}

/**
 * Prepare game data for competitive mode
 * All players get identical data for fair competition
 * @param {Object} gameData Base game data
 * @param {number} playerId Player ID
 * @returns {Promise<Object>} Competitive game data
 */
async function prepareCompetitiveGameData(gameData, playerId) {
  logger.debug('Preparing competitive game data', { player_id: playerId });

  // In competitive mode, all players get the same data
  return {
    mode: 'competitive',
    checkpoints: gameData.checkpoints,
    puzzles: gameData.puzzles,
    config: {
      ...gameData.config,
      // Competitive-specific config
      leaderboard_enabled: true,
      time_tracking: true,
      live_updates: false, // Offline play
      score_calculation: 'time_and_accuracy'
    },
    features: {
      leaderboard: true,
      time_trial: true,
      score_comparison: true,
      route_optimization: false // Fixed route for fairness
    }
  };
}

/**
 * Prepare game data for individual mode
 * Each player gets personalized experience
 * @param {Object} gameData Base game data
 * @param {number} playerId Player ID
 * @returns {Promise<Object>} Individual game data
 */
async function prepareIndividualGameData(gameData, playerId) {
  logger.debug('Preparing individual game data', { player_id: playerId });

  // Create player-specific variations
  const personalizedCheckpoints = await personalizeCheckpoints(gameData.checkpoints, playerId);
  const personalizedPuzzles = await personalizePuzzles(gameData.puzzles, playerId);

  return {
    mode: 'individual',
    checkpoints: personalizedCheckpoints,
    puzzles: personalizedPuzzles,
    config: {
      ...gameData.config,
      // Individual-specific config
      leaderboard_enabled: false,
      time_tracking: false,
      adaptive_difficulty: true,
      exploration_mode: true
    },
    features: {
      leaderboard: false,
      time_trial: false,
      score_comparison: false,
      route_optimization: true,
      adaptive_hints: true,
      exploration_rewards: true
    }
  };
}

/**
 * Prepare game data for team mode
 * @param {Object} gameData Base game data
 * @param {number} playerId Player ID
 * @returns {Promise<Object>} Team game data
 */
async function prepareTeamGameData(gameData, playerId) {
  logger.debug('Preparing team game data', { player_id: playerId });

  // Team mode implementation (future enhancement)
  return {
    mode: 'team',
    checkpoints: gameData.checkpoints,
    puzzles: gameData.puzzles,
    config: {
      ...gameData.config,
      team_collaboration: true,
      shared_progress: true
    },
    features: {
      team_chat: true,
      shared_objectives: true,
      role_assignments: true
    }
  };
}

/**
 * Prepare game data for tutorial mode
 * @param {Object} gameData Base game data
 * @param {number} playerId Player ID
 * @returns {Promise<Object>} Tutorial game data
 */
async function prepareTutorialGameData(gameData, playerId) {
  logger.debug('Preparing tutorial game data', { player_id: playerId });

  // Simplified version for learning
  const tutorialCheckpoints = gameData.checkpoints.slice(0, 2); // Only first 2 checkpoints
  const tutorialPuzzles = gameData.puzzles.slice(0, 1); // Only first puzzle

  return {
    mode: 'tutorial',
    checkpoints: tutorialCheckpoints,
    puzzles: tutorialPuzzles,
    config: {
      ...gameData.config,
      tutorial_mode: true,
      hints_enabled: true,
      simplified_ui: true
    },
    features: {
      guided_tour: true,
      extra_hints: true,
      step_by_step: true,
      skip_allowed: true
    }
  };
}

/**
 * Personalize checkpoints for individual players
 * @param {Array} checkpoints Base checkpoints
 * @param {number} playerId Player ID
 * @returns {Promise<Array>} Personalized checkpoints
 */
async function personalizeCheckpoints(checkpoints, playerId) {
  // Create deterministic but unique order based on player ID
  const seed = playerId * 17; // Simple seeding
  const personalizedOrder = [...checkpoints];
  
  // Keep start and finish in place, shuffle middle ones
  const start = personalizedOrder.find(cp => cp.checkpoint_type === 'start');
  const finish = personalizedOrder.find(cp => cp.checkpoint_type === 'finish');
  const middle = personalizedOrder.filter(cp => 
    cp.checkpoint_type !== 'start' && cp.checkpoint_type !== 'finish'
  );

  // Simple deterministic shuffle based on player ID
  for (let i = middle.length - 1; i > 0; i--) {
    const j = Math.floor(((seed + i) * 9301 + 49297) % 233280) % (i + 1);
    [middle[i], middle[j]] = [middle[j], middle[i]];
  }

  // Rebuild order
  const result = [];
  if (start) result.push(start);
  result.push(...middle);
  if (finish) result.push(finish);

  // Update order indices
  result.forEach((checkpoint, index) => {
    checkpoint.order_index = index + 1;
  });

  logger.debug('Personalized checkpoint order', {
    player_id: playerId,
    original_order: checkpoints.map(cp => cp.name),
    personalized_order: result.map(cp => cp.name)
  });

  return result;
}

/**
 * Personalize puzzles for individual players
 * @param {Array} puzzles Base puzzles
 * @param {number} playerId Player ID
 * @returns {Promise<Array>} Personalized puzzles
 */
async function personalizePuzzles(puzzles, playerId) {
  // For now, just return same puzzles
  // Future: Could vary difficulty, select subset, reorder questions
  
  return puzzles.map(puzzle => ({
    ...puzzle,
    // Could add player-specific hints or difficulty adjustments
    difficulty_adjustment: calculateDifficultyAdjustment(playerId),
    hints_available: true
  }));
}

/**
 * Calculate difficulty adjustment for player
 * @param {number} playerId Player ID
 * @returns {string} Difficulty level
 */
function calculateDifficultyAdjustment(playerId) {
  // Simple algorithm based on player ID
  const adjustment = playerId % 3;
  
  switch (adjustment) {
    case 0: return 'normal';
    case 1: return 'easy';
    case 2: return 'hard';
    default: return 'normal';
  }
}

/**
 * Get leaderboard data for competitive games
 * @param {number} gameId Game ID
 * @returns {Promise<Array>} Leaderboard data
 */
async function getLeaderboard(gameId) {
  const result = await query(`
    SELECT 
      p.name as player_name,
      p.total_score,
      p.completion_time,
      p.game_completed,
      pg.completed_at
    FROM neoquest.players p
    JOIN neoquest.player_games pg ON p.id = pg.player_id
    WHERE pg.game_id = $1 AND p.game_completed = true
    ORDER BY p.completion_time ASC, p.total_score DESC
    LIMIT 10
  `, [gameId]);

  return result.rows;
}

module.exports = {
  getGameDataForPlayer,
  getLeaderboard,
  getBaseGameData,
  getPlayerGameInfo
};