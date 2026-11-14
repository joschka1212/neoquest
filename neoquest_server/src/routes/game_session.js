// routes/game_session.js
// Game Session Management API for coordinated multiplayer starts
// Supports 60-80+ players with polling-based status updates
// API Endpoints:
//
// GET  /api/session/status                - Get current session status (for polling)
// POST /api/session/ready                 - Player marks ready (token required)
// POST /api/session/admin/start           - Admin starts game session
// POST /api/session/admin/countdown/:seconds - Admin sets countdown
// GET  /api/session/admin/players          - Admin view of all players
// POST /api/session/admin/reset           - Admin resets session
//
// 20250714 07:23 V1.0 File created for coordinated game starts
// 20250801 Express 5.x comtatiblity implemented

const express = require('express');
const router = express.Router();
const { validateToken } = require('../utils/tokenGenerator');

// Database connection: gemeinsamer Pool aus config/database.js (Zugangsdaten aus .env)
const { pool } = require('../config/database');

// Session status enum
const SESSION_STATUS = {
  REGISTRATION: 'registration',
  WAITING: 'waiting',
  COUNTDOWN: 'countdown',
  STARTED: 'started',
  PAUSED: 'paused',
  FINISHED: 'finished'
};

// In-memory session state for fast polling responses
let currentSessionState = {
  status: SESSION_STATUS.REGISTRATION,
  countdown: 0,
  message: 'Players can register and mark ready',
  startTime: null,
  readyPlayers: 0,
  totalPlayers: 0,
  lastUpdated: new Date()
};

// ===============================================
// DATABASE SETUP
// ===============================================

/**
 * Prueft, ob die Session-Tabellen existieren.
 * Angelegt werden sie ausschliesslich ueber die Migration
 * neoquest_db/migrations/20250714000001-add-game-session-managment.js
 * (der Server laeuft mit dem eingeschraenkten User neoquest_app ohne DDL-Rechte).
 */
async function initializeSessionTables() {
  try {
    const result = await pool.query(
      "SELECT to_regclass('neoquest.coordinated_sessions') AS tbl"
    );
    if (!result.rows[0].tbl) {
      console.error('Tabelle neoquest.coordinated_sessions fehlt - bitte in neoquest_db "npm run migrate:up" ausfuehren.');
    }
  } catch (error) {
    console.error('Error checking session tables:', error.message);
  }
}

// Initialize on module load
initializeSessionTables();

// ===============================================
// HELPER FUNCTIONS
// ===============================================

/**
 * Update in-memory session state from database
 */
async function refreshSessionState() {
  const client = await pool.connect();
  
  try {
    // Get current session
    const sessionResult = await client.query(`
      SELECT * FROM neoquest.coordinated_sessions 
      ORDER BY created_at DESC LIMIT 1
    `);

    // Count ready players
    const playersResult = await client.query(`
      SELECT 
        COUNT(*) as total_players,
        COUNT(*) FILTER (WHERE session_ready = true) as ready_players
      FROM neoquest.players 
      WHERE is_active = true
    `);

    if (sessionResult.rows.length > 0) {
      const session = sessionResult.rows[0];
      const playerCounts = playersResult.rows[0];

      // Calculate remaining countdown if active
      let remainingCountdown = 0;
      if (session.status === 'countdown' && session.countdown_start_time) {
        const elapsed = Math.floor((new Date() - new Date(session.countdown_start_time)) / 1000);
        remainingCountdown = Math.max(0, session.countdown_seconds - elapsed);
        
        // Auto-transition to started if countdown finished
        if (remainingCountdown === 0 && session.status === 'countdown') {
          await client.query(`
            UPDATE neoquest.coordinated_sessions 
            SET status = 'started', actual_start_time = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
            WHERE id = $1
          `, [session.id]);
          
          currentSessionState.status = SESSION_STATUS.STARTED;
          currentSessionState.startTime = new Date();
          currentSessionState.message = 'Game started! Begin your mission!';
        }
      }

      currentSessionState = {
        status: session.status,
        countdown: remainingCountdown,
        message: session.admin_message || getDefaultMessage(session.status),
        startTime: session.actual_start_time,
        readyPlayers: parseInt(playerCounts.ready_players) || 0,
        totalPlayers: parseInt(playerCounts.total_players) || 0,
        lastUpdated: new Date(),
        sessionConfig: session.session_config || {}
      };
    }

  } catch (error) {
    console.error('Error refreshing session state:', error);
  } finally {
    client.release();
  }
}

/**
 * Get default message for session status
 */
function getDefaultMessage(status) {
  const messages = {
    'registration': 'Players can register and mark themselves ready',
    'waiting': 'All players ready! Waiting for admin to start the game',
    'countdown': 'Game starting soon! Get ready...',
    'started': 'Game is running! Navigate to your checkpoints',
    'paused': 'Game temporarily paused by admin',
    'finished': 'Game session completed. Thank you for playing!'
  };
  return messages[status] || 'Game session in progress';
}

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

/**
 * Admin authentication middleware
 */
function requireAdmin(req, res, next) {
  const adminKey = req.headers['x-admin-key'] || req.body.admin_key || req.query.admin_key;
  
  if (!adminKey || adminKey !== (process.env.ADMIN_KEY || 'admin123')) {
    return res.status(403).json({
      error: 'Admin access required',
      message: 'Provide valid admin key'
    });
  }
  
  next();
}

// ===============================================
// PLAYER ENDPOINTS (For Polling)
// ===============================================

/**
 * GET /api/session/status
 * Get current session status (main polling endpoint for players)
 */
router.get('/status', async (req, res) => {
  try {
    // Refresh from database every time to ensure accuracy
    await refreshSessionState();
    
    // Return lightweight response optimized for frequent polling
    res.json({
      success: true,
      session: {
        status: currentSessionState.status,
        countdown: currentSessionState.countdown,
        message: currentSessionState.message,
        startTime: currentSessionState.startTime,
        readyPlayers: currentSessionState.readyPlayers,
        totalPlayers: currentSessionState.totalPlayers
      },
      polling: {
        lastUpdated: currentSessionState.lastUpdated,
        recommendedInterval: currentSessionState.status === 'countdown' ? 1000 : 2000,
        nextPollAt: new Date(Date.now() + (currentSessionState.status === 'countdown' ? 1000 : 2000))
      }
    });
    
  } catch (error) {
    console.error('Session status error:', error);
    res.status(500).json({ 
      error: 'Failed to get session status',
      details: error.message 
    });
  }
});

/**
 * POST /api/session/ready
 * Player marks themselves as ready (token required)
 */
router.post('/ready', requireValidToken, async (req, res) => {
  const client = await pool.connect();
  
  try {
    const playerId = req.player.id;
    const playerName = req.player.name;
    
    // Check if registration is still open
    await refreshSessionState();
    
    if (currentSessionState.status !== SESSION_STATUS.REGISTRATION && 
        currentSessionState.status !== SESSION_STATUS.WAITING) {
      return res.status(400).json({
        error: 'Registration closed',
        message: 'Cannot mark ready - game session already started or finished'
      });
    }

    await client.query('BEGIN');
    
    // Mark player as ready
    await client.query(`
      UPDATE neoquest.players 
      SET 
        session_ready = true,
        ready_timestamp = CURRENT_TIMESTAMP,
        session_joined_at = COALESCE(session_joined_at, CURRENT_TIMESTAMP)
      WHERE id = $1
    `, [playerId]);
    
    // Check if we should auto-transition to waiting status
    const playersResult = await client.query(`
      SELECT 
        COUNT(*) as total_players,
        COUNT(*) FILTER (WHERE session_ready = true) as ready_players
      FROM neoquest.players 
      WHERE is_active = true
    `);
    
    const { total_players, ready_players } = playersResult.rows[0];
    
    // If we have players and at least 70% are ready, transition to waiting
    if (total_players > 0 && ready_players / total_players >= 0.7) {
      await client.query(`
        UPDATE neoquest.coordinated_sessions 
        SET status = 'waiting', admin_message = 'Most players ready! Waiting for admin to start', updated_at = CURRENT_TIMESTAMP
        WHERE id IN (SELECT id FROM neoquest.coordinated_sessions ORDER BY created_at DESC LIMIT 1)
      `);
    }
    
    await client.query('COMMIT');
    
    res.json({
      success: true,
      message: 'Marked as ready successfully',
      player: {
        id: playerId,
        name: playerName,
        ready: true
      },
      session: {
        readyPlayers: parseInt(ready_players),
        totalPlayers: parseInt(total_players),
        readyPercentage: Math.round((ready_players / total_players) * 100)
      }
    });
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Ready marking error:', error);
    res.status(500).json({ 
      error: 'Failed to mark ready',
      details: error.message 
    });
  } finally {
    client.release();
  }
});

// ===============================================
// ADMIN ENDPOINTS
// ===============================================

/**
 * POST /api/session/admin/start
 * Admin starts the game session immediately
 */
router.post('/admin/start', requireAdmin, async (req, res) => {
  const client = await pool.connect();
  
  try {
    const { message } = req.body;
    
    await client.query('BEGIN');
    
    // Create or update session to started
    await client.query(`
      INSERT INTO neoquest.coordinated_sessions (status, actual_start_time, admin_message, updated_at)
      VALUES ('started', CURRENT_TIMESTAMP, $1, CURRENT_TIMESTAMP)
      ON CONFLICT ON CONSTRAINT coordinated_sessions_pkey 
      DO UPDATE SET 
        status = 'started',
        actual_start_time = CURRENT_TIMESTAMP,
        admin_message = $1,
        updated_at = CURRENT_TIMESTAMP
    `, [message || 'Game started by admin! Begin your mission!']);
    
    await client.query('COMMIT');
    
    // Refresh state
    await refreshSessionState();
    
    res.json({
      success: true,
      message: 'Game session started successfully',
      session: {
        status: SESSION_STATUS.STARTED,
        startTime: new Date(),
        readyPlayers: currentSessionState.readyPlayers,
        totalPlayers: currentSessionState.totalPlayers
      }
    });
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Admin start error:', error);
    res.status(500).json({ 
      error: 'Failed to start session',
      details: error.message 
    });
  } finally {
    client.release();
  }
});

/**
 * POST /api/session/admin/countdown/:seconds
 * Admin starts countdown before game start
 */
router.post('/admin/countdown/:seconds', requireAdmin, async (req, res) => {
  const client = await pool.connect();
  
  try {
    const countdownSeconds = parseInt(req.params.seconds);
    const { message } = req.body;
    
    if (!countdownSeconds || countdownSeconds < 5 || countdownSeconds > 300) {
      return res.status(400).json({
        error: 'Invalid countdown',
        message: 'Countdown must be between 5 and 300 seconds'
      });
    }
    
    await client.query('BEGIN');
    
    // Create or update session with countdown
    await client.query(`
      INSERT INTO neoquest.coordinated_sessions 
      (status, countdown_seconds, countdown_start_time, admin_message, updated_at)
      VALUES ('countdown', $1, CURRENT_TIMESTAMP, $2, CURRENT_TIMESTAMP)
      ON CONFLICT ON CONSTRAINT coordinated_sessions_pkey 
      DO UPDATE SET 
        status = 'countdown',
        countdown_seconds = $1,
        countdown_start_time = CURRENT_TIMESTAMP,
        admin_message = $2,
        updated_at = CURRENT_TIMESTAMP
    `, [countdownSeconds, message || `Game starting in ${countdownSeconds} seconds! Get ready!`]);
    
    await client.query('COMMIT');
    
    // Refresh state
    await refreshSessionState();
    
    res.json({
      success: true,
      message: `Countdown started: ${countdownSeconds} seconds`,
      session: {
        status: SESSION_STATUS.COUNTDOWN,
        countdown: countdownSeconds,
        countdownStartTime: new Date(),
        expectedStartTime: new Date(Date.now() + (countdownSeconds * 1000)),
        readyPlayers: currentSessionState.readyPlayers,
        totalPlayers: currentSessionState.totalPlayers
      }
    });
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Admin countdown error:', error);
    res.status(500).json({ 
      error: 'Failed to start countdown',
      details: error.message 
    });
  } finally {
    client.release();
  }
});

/**
 * GET /api/session/admin/players
 * Admin view of all players and their ready status
 */
router.get('/admin/players', requireAdmin, async (req, res) => {
  const client = await pool.connect();
  
  try {
    const playersResult = await client.query(`
      SELECT 
        p.id,
        p.name,
        p.token,
        p.email,
        p.game_id,
        p.game_title,
        p.session_ready,
        p.ready_timestamp,
        p.session_joined_at,
        p.registered_at,
        p.is_active,
        g.name as game_name
      FROM neoquest.players p
      LEFT JOIN neoquest.games g ON p.game_id = g.id
      WHERE p.is_active = true
      ORDER BY p.ready_timestamp DESC NULLS LAST, p.registered_at DESC
    `);
    
    const players = playersResult.rows;
    
    // Calculate statistics
    const stats = {
      totalPlayers: players.length,
      readyPlayers: players.filter(p => p.session_ready).length,
      pendingPlayers: players.filter(p => !p.session_ready).length,
      readyPercentage: players.length > 0 ? 
        Math.round((players.filter(p => p.session_ready).length / players.length) * 100) : 0
    };
    
    // Group by game
    const gameGroups = {};
    players.forEach(player => {
      const gameId = player.game_id || 'unknown';
      if (!gameGroups[gameId]) {
        gameGroups[gameId] = {
          gameId: gameId,
          gameName: player.game_name || 'Unknown Game',
          players: [],
          readyCount: 0,
          totalCount: 0
        };
      }
      gameGroups[gameId].players.push(player);
      gameGroups[gameId].totalCount++;
      if (player.session_ready) {
        gameGroups[gameId].readyCount++;
      }
    });
    
    await refreshSessionState();
    
    res.json({
      success: true,
      session: currentSessionState,
      players: players,
      statistics: stats,
      gameGroups: Object.values(gameGroups),
      lastUpdated: new Date()
    });
    
  } catch (error) {
    console.error('Admin players error:', error);
    res.status(500).json({ 
      error: 'Failed to get players overview',
      details: error.message 
    });
  } finally {
    client.release();
  }
});

/**
 * POST /api/session/admin/reset
 * Admin resets the session to registration state
 */
router.post('/admin/reset', requireAdmin, async (req, res) => {
  const client = await pool.connect();
  
  try {
    const { message } = req.body;
    
    await client.query('BEGIN');
    
    // Reset all players to not ready
    await client.query(`
      UPDATE neoquest.players 
      SET session_ready = false, ready_timestamp = NULL, session_joined_at = NULL
      WHERE is_active = true
    `);
    
    // Create new registration session
    await client.query(`
      INSERT INTO neoquest.coordinated_sessions 
      (status, countdown_seconds, admin_message, updated_at)
      VALUES ('registration', 0, $1, CURRENT_TIMESTAMP)
    `, [message || 'Session reset - players can register and mark ready again']);
    
    await client.query('COMMIT');
    
    // Refresh state
    await refreshSessionState();
    
    res.json({
      success: true,
      message: 'Session reset successfully',
      session: {
        status: SESSION_STATUS.REGISTRATION,
        readyPlayers: 0,
        totalPlayers: currentSessionState.totalPlayers,
        message: message || 'Session reset - players can register and mark ready again'
      }
    });
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Admin reset error:', error);
    res.status(500).json({ 
      error: 'Failed to reset session',
      details: error.message 
    });
  } finally {
    client.release();
  }
});

// ===============================================
// UTILITY ENDPOINTS
// ===============================================

/**
 * GET /api/session/test
 * Test endpoint to verify session routes
 */
router.get('/test', (req, res) => {
  res.json({ 
    message: 'Game session routes working!',
    currentStatus: currentSessionState.status,
    timestamp: new Date().toISOString(),
    supportedStatuses: Object.values(SESSION_STATUS)
  });
});

module.exports = router;