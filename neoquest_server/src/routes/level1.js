// neoquest_server/src/routes/level1.js

// ===============================================
// NeoQuest Content-Session API Design
// Download Content → Play Offline (w.o. Server Connection) → Upload Session
// All Complexity Levels (1-5)
// ===============================================
// neoquest_server/src/routes/level1.js
// FIXED FOR EXPRESS 5.x - Optional parameter routes corrected
// neoquest_server/src/routes/level1.js
// FIXED FOR EXPRESS 5.x - Optional parameter routes corrected

/**
 * Level1 Routes - Content-Session API Design
 * Download Content → Play Offline → Upload Session
 * All Complexity Levels (1-5)
 */

const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;
const crypto = require('crypto');

const router = express.Router();

// Database connection: gemeinsamer Pool aus config/database.js (Zugangsdaten aus .env)
const { pool } = require('../config/database');
const { requireAdmin } = require('../middleware/adminAuth');

// File upload configuration
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const uploadDir = path.join(__dirname, '../uploads');
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({ 
    storage: storage,
    limits: {
        fileSize: 50 * 1024 * 1024
    }
});

// ===============================================
// ADMIN & TOKEN MANAGEMENT
// ===============================================

/**
 * POST /api/level1/admin/generate-tokens
 * Generate QR code tokens for a specific game
 */
router.post('/admin/generate-tokens', requireAdmin, async (req, res) => {
    const client = await pool.connect();

    try {
        const {
            game_id,
            count = 1
        } = req.body;

        const gameResult = await client.query(`
            SELECT id, name, game_type, complexity_level, is_active 
            FROM neoquest.games 
            WHERE id = $1 AND is_active = true
        `, [game_id]);
        
        if (gameResult.rows.length === 0) {
            return res.status(404).json({ 
                success: false, 
                error: 'Game not found or inactive' 
            });
        }
        
        const game = gameResult.rows[0];
        
        await client.query('BEGIN');
        
        const tokens = [];
        
        for (let i = 0; i < count; i++) {
            const token = 'QR_TOKEN_' + crypto.randomBytes(8).toString('hex').toUpperCase();
            const qrCodeContent = `NEOQUEST:${token}:${game.name}`;
            
            const playerResult = await client.query(`
                INSERT INTO neoquest.players 
                (token, name, game_id, game_title, qr_code_content, is_active, player_config)
                VALUES ($1, $2, $3, $4, $5, true, $6)
                RETURNING id, token
            `, [
                token,
                `Player-${i + 1}`,
                game_id,
                game.name,
                qrCodeContent,
                JSON.stringify({ 
                    generated_at: new Date(),
                    generated_by: 'admin',
                    auto_generated: true 
                })
            ]);
            
            const player = playerResult.rows[0];
            
            tokens.push({
                player_id: player.id,
                token: token,
                qr_code_content: qrCodeContent,
                qr_code_url: `${req.protocol}://${req.get('host')}/api/level1/admin/qr/${token}`,
                player_name: `Player-${i + 1}`,
                game_name: game.name
            });
        }
        
        await client.query('COMMIT');
        
        res.json({
            success: true,
            game: {
                id: game.id,
                name: game.name,
                game_type: game.game_type,
                complexity_level: game.complexity_level
            },
            tokens_generated: count,
            tokens: tokens,
            message: `Successfully generated ${count} QR tokens for ${game.name}`
        });
        
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Token generation error:', error);
        res.status(500).json({ 
            success: false, 
            error: 'Failed to generate tokens' 
        });
    } finally {
        client.release();
    }
});

/**
 * GET /api/level1/admin/qr/:token
 * Generate QR code image for a token
 */
router.get('/admin/qr/:token', requireAdmin, async (req, res) => {
    try {
        const { token } = req.params;
        const { format = 'json', size = '200' } = req.query;
        
        const result = await pool.query(`
            SELECT p.*, g.name as game_name 
            FROM neoquest.players p
            JOIN neoquest.games g ON p.game_id = g.id
            WHERE p.token = $1 AND p.is_active = true
        `, [token]);

        if (result.rows.length === 0) {
            return res.status(404).json({ 
                success: false, 
                error: 'Token not found' 
            });
        }
        
        const player = result.rows[0];
        
        if (format === 'json') {
            res.json({
                success: true,
                qr_data: {
                    content: player.qr_code_content,
                    token: player.token,
                    player_name: player.name,
                    game_name: player.game_name,
                    game_id: player.game_id
                },
                qr_code_content: player.qr_code_content,
                suggested_qr_generators: [
                    `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(player.qr_code_content)}`
                ]
            });
        } else {
            const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(player.qr_code_content)}`;
            res.redirect(qrUrl);
        }
        
    } catch (error) {
        console.error('QR generation error:', error);
        res.status(500).json({ 
            success: false, 
            error: 'Failed to generate QR code' 
        });
    }
});

/**
 * GET /api/level1/admin/tokens/:game_id
 * List all tokens for a specific game
 */
router.get('/admin/tokens/:game_id', requireAdmin, async (req, res) => {
    try {
        const { game_id } = req.params;

        const result = await pool.query(`
            SELECT p.id, p.token, p.name, p.qr_code_content, p.registered_at, p.is_active,
                   g.name as game_name
            FROM neoquest.players p
            JOIN neoquest.games g ON p.game_id = g.id
            WHERE p.game_id = $1
            ORDER BY p.registered_at DESC
        `, [game_id]);
        
        const tokens = result.rows.map(row => ({
            player_id: row.id,
            token: row.token,
            player_name: row.name,
            qr_code_content: row.qr_code_content,
            qr_code_url: `${req.protocol}://${req.get('host')}/api/level1/admin/qr/${row.token}`,
            game_name: row.game_name,
            registered_at: row.registered_at,
            is_active: row.is_active
        }));
        
        res.json({
            success: true,
            game_id: parseInt(game_id),
            total_tokens: tokens.length,
            active_tokens: tokens.filter(t => t.is_active).length,
            tokens: tokens
        });
        
    } catch (error) {
        console.error('Token list error:', error);
        res.status(500).json({ 
            success: false, 
            error: 'Failed to retrieve tokens' 
        });
    }
});

/**
 * DELETE /api/level1/admin/token/:token  
 * Deactivate a specific token
 */
router.delete('/admin/token/:token', requireAdmin, async (req, res) => {
    try {
        const { token } = req.params;

        const result = await pool.query(`
            UPDATE neoquest.players 
            SET is_active = false 
            WHERE token = $1 
            RETURNING id, name, token
        `, [token]);
        
        if (result.rows.length === 0) {
            return res.status(404).json({ 
                success: false, 
                error: 'Token not found' 
            });
        }
        
        res.json({
            success: true,
            message: 'Token deactivated successfully',
            deactivated_token: result.rows[0]
        });
        
    } catch (error) {
        console.error('Token deactivation error:', error);
        res.status(500).json({ 
            success: false, 
            error: 'Failed to deactivate token' 
        });
    }
});

// ===============================================
// PLAYER REGISTRATION & AUTHENTICATION
// ===============================================

/**
 * POST /api/level1/auth/register
 * Register player with QR code token
 */
router.post('/auth/register', async (req, res) => {
    const client = await pool.connect();
    
    try {
        const { qr_content, player_name, device_info } = req.body;
        
        if (!qr_content) {
            return res.status(400).json({ 
                success: false, 
                error: 'QR code content required' 
            });
        }
        
        const qrParts = qr_content.split(':');
        if (qrParts.length !== 3 || qrParts[0] !== 'NEOQUEST') {
            return res.status(400).json({ 
                success: false, 
                error: 'Invalid QR code format' 
            });
        }
        
        const [, tokenSuffix, game_title] = qrParts;  
        const token = 'QR_TOKEN_' + tokenSuffix;

        await client.query('BEGIN');
        
        const playerResult = await client.query(`
            SELECT p.*, g.name as game_name, g.complexity_level, g.game_config, g.description
            FROM neoquest.players p
            JOIN neoquest.games g ON p.game_id = g.id
            WHERE p.token = $1 AND p.is_active = true AND g.is_active = true
        `, [token]);

        if (playerResult.rows.length === 0) {
            return res.status(404).json({ 
                success: false, 
                error: 'Invalid token or game not found' 
            });
        }
        
        const player = playerResult.rows[0];
        
        if (player_name && player_name !== player.name) {
            await client.query(`
                UPDATE neoquest.players 
                SET name = $1, player_config = player_config || $2
                WHERE id = $3
            `, [player_name, JSON.stringify({ device_info, registered_at: new Date() }), player.id]);
        }
        
        await client.query('COMMIT');
        
        res.json({
            success: true,
            player: {
                id: player.id,
                token: player.token,
                name: player_name || player.name,
                game_id: player.game_id,
                game_name: player.game_name,
                game_title: player.game_title,
                complexity_level: player.complexity_level,
                description: player.description
            },
            offline_mode: true,
            next_step: 'download_game_content',
            message: 'Player registered successfully - ready for content download'
        });
        
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Registration error:', error);
        res.status(500).json({ 
            success: false, 
            error: 'Registration failed' 
        });
    } finally {
        client.release();
    }
});

/**
 * POST /api/level1/auth/verify
 * Verify player token and get basic info
 */
router.post('/auth/verify', async (req, res) => {
    try {
        const { token } = req.body;
        
        const result = await pool.query(`
            SELECT p.*, g.name as game_name, g.complexity_level, g.description
            FROM neoquest.players p
            JOIN neoquest.games g ON p.game_id = g.id
            WHERE p.token = $1 AND p.is_active = true AND g.is_active = true
        `, [token]);
        
        if (result.rows.length === 0) {
            return res.status(404).json({ 
                success: false, 
                error: 'Invalid token or game not available' 
            });
        }
        
        const player = result.rows[0];
        
        res.json({
            success: true,
            player: {
                id: player.id,
                token: player.token,
                name: player.name,
                game_id: player.game_id,
                game_name: player.game_name,
                complexity_level: player.complexity_level,
                description: player.description
            },
            offline_mode: true,
            next_step: 'download_game_content'
        });
        
    } catch (error) {
        console.error('Verify error:', error);
        res.status(500).json({ 
            success: false, 
            error: 'Verification failed' 
        });
    }
});

// ===============================================
// GAME CONTENT DOWNLOAD
// ===============================================

/**
 * GET /api/level1/content/game/:game_id
 * Download complete game content for offline gaming
 */
router.get('/content/game/:game_id', async (req, res) => {
    try {
        const { game_id } = req.params;
        const { token } = req.query;
        
        const playerCheck = await pool.query(`
            SELECT p.id, p.name FROM neoquest.players p
            WHERE p.token = $1 AND p.game_id = $2 AND p.is_active = true
        `, [token, game_id]);
        
        if (playerCheck.rows.length === 0) {
            return res.status(403).json({ 
                success: false, 
                error: 'Access denied to this game' 
            });
        }
        
        const player = playerCheck.rows[0];
        
        const gameResult = await pool.query(`
            SELECT * FROM neoquest.games WHERE id = $1 AND is_active = true
        `, [game_id]);
        
        if (gameResult.rows.length === 0) {
            return res.status(404).json({ 
                success: false, 
                error: 'Game not found' 
            });
        }
        
        const game = gameResult.rows[0];
        
        const checkpointsResult = await pool.query(`
            SELECT id, checkpoint_order, name, description, latitude, longitude, 
                   radius, checkpoint_type, qr_code_content, is_required, 
                   min_stay_duration, checkpoint_config
            FROM neoquest.checkpoints 
            WHERE game_id = $1 
            ORDER BY checkpoint_order
        `, [game_id]);
        
        const sessionPrep = {
            base_points: game.game_config?.scoring?.base_points || 1000,
            time_tracking: game.game_config?.features?.time_bonus || false,
            offline_storage_key: `neoquest_${game_id}_${player.id}_${Date.now()}`
        };
        
        res.json({
            success: true,
            content_mode: true,
            content_info: {
                game_id: parseInt(game_id),
                player_id: player.id,
                player_name: player.name,
                downloaded_at: new Date(),
                expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000)
            },
            game: {
                id: game.id,
                name: game.name,
                description: game.description,
                game_type: game.game_type,
                complexity_level: game.complexity_level,
                game_config: game.game_config
            },
            checkpoints: checkpointsResult.rows,
            session_prep: sessionPrep
        });
        
    } catch (error) {
        console.error('Game content error:', error);
        res.status(500).json({ 
            success: false, 
            error: 'Failed to retrieve game content' 
        });
    }
});

/**
 * GET /api/level1/content/media/:game_id/:file_name
 * Download media files for local storage
 */
router.get('/content/media/:game_id/:file_name', async (req, res) => {
    try {
        const { game_id, file_name } = req.params;
        const { token } = req.query;
        
        const playerCheck = await pool.query(`
            SELECT id FROM neoquest.players 
            WHERE token = $1 AND game_id = $2 AND is_active = true
        `, [token, game_id]);
        
        if (playerCheck.rows.length === 0) {
            return res.status(403).json({ 
                success: false, 
                error: 'Access denied' 
            });
        }
        
        const mediaPath = path.join(__dirname, '../media', game_id.toString(), file_name);
        
        try {
            await fs.access(mediaPath);
            res.sendFile(path.resolve(mediaPath));
        } catch (error) {
            res.status(404).json({ 
                success: false, 
                error: 'Media file not found' 
            });
        }
        
    } catch (error) {
        console.error('Media download error:', error);
        res.status(500).json({ 
            success: false, 
            error: 'Failed to download media' 
        });
    }
});

// ===============================================
// SESSION UPLOAD (AFTER LOCAL GAMING)
// ===============================================

/**
 * POST /api/level1/session/upload
 * Upload complete game session after local gaming
 */
router.post('/session/upload', upload.array('media_files', 20), async (req, res) => {
    const client = await pool.connect();
    
    try {
        const {
            token,
            game_id,
            session_data,
            gps_track,
            final_score,
            session_metadata
        } = req.body;
        
        const sessionInfo = JSON.parse(session_data);
        const gpsPoints = JSON.parse(gps_track || '[]');
        const metadata = JSON.parse(session_metadata || '{}');
        
        await client.query('BEGIN');
        
        const playerResult = await client.query(`
            SELECT p.*, g.game_config FROM neoquest.players p
            JOIN neoquest.games g ON p.game_id = g.id
            WHERE p.token = $1 AND p.game_id = $2 AND p.is_active = true
        `, [token, game_id]);
        
        if (playerResult.rows.length === 0) {
            return res.status(404).json({ 
                success: false, 
                error: 'Player or game not found' 
            });
        }
        
        const player = playerResult.rows[0];
        
        const sessionToken = 'SESSION_' + crypto.randomBytes(16).toString('hex');
        
        const sessionResult = await client.query(`
            INSERT INTO neoquest.game_sessions 
            (player_id, game_id, session_token, start_time, end_time, 
             game_state, session_status, final_score)
            VALUES ($1, $2, $3, $4, $5, $6, 'completed', $7)
            RETURNING id
        `, [
            player.id,
            game_id,
            sessionToken,
            new Date(sessionInfo.start_time),
            new Date(sessionInfo.end_time),
            JSON.stringify({
                ...sessionInfo,
                session_upload: true,
                upload_timestamp: new Date(),
                device_metadata: metadata
            }),
            final_score
        ]);
        
        await client.query('COMMIT');
        
        res.json({
            success: true,
            upload_summary: {
                session_id: sessionResult.rows[0].id,
                session_token: sessionToken,
                final_score: final_score,
                total_time_seconds: Math.floor((new Date(sessionInfo.end_time) - new Date(sessionInfo.start_time)) / 1000)
            },
            message: 'Session uploaded successfully!'
        });
        
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Session upload error:', error);
        res.status(500).json({ 
            success: false, 
            error: 'Failed to upload session data',
            details: error.message
        });
    } finally {
        client.release();
    }
});

// ===============================================
// LEADERBOARDS & STATISTICS
// ===============================================

/**
 * GET /api/level1/session/leaderboard (all games)
 * GET /api/level1/session/leaderboard/:game_id (specific game)
 */
router.get('/session/leaderboard', async (req, res) => {
    await getLeaderboard(req, res, null);
});

router.get('/session/leaderboard/:game_id', async (req, res) => {
    await getLeaderboard(req, res, req.params.game_id);
});

async function getLeaderboard(req, res, game_id) {
    try {
        const { limit = 10, type = 'overall' } = req.query;
        
        let queryText = `
            SELECT player_name, final_score, completion_time, 
                   additional_metrics, created_at, rank_position
            FROM neoquest.leaderboards 
            WHERE leaderboard_type = $1
        `;
        
        const params = [type];
        
        if (game_id) {
            queryText += ' AND game_id = $2';
            params.push(game_id);
            queryText += ' ORDER BY rank_position ASC, final_score DESC, completion_time ASC LIMIT $3';
            params.push(parseInt(limit));
        } else {
            queryText += ' ORDER BY rank_position ASC, final_score DESC, completion_time ASC LIMIT $2';
            params.push(parseInt(limit));
        }
        
        const result = await pool.query(queryText, params);
        
        res.json({
            success: true,
            leaderboard: result.rows.map(row => ({
                ...row,
                additional_metrics: row.additional_metrics || {}
            })),
            game_id: game_id ? parseInt(game_id) : null,
            type: type,
            total_entries: result.rows.length,
            last_updated: new Date()
        });
        
    } catch (error) {
        console.error('Leaderboard error:', error);
        res.status(500).json({ 
            success: false, 
            error: 'Failed to retrieve leaderboard' 
        });
    }
}

/**
 * GET /api/level1/session/stats/:game_id
 * Get game statistics and analytics
 */
router.get('/session/stats/:game_id', async (req, res) => {
    try {
        const { game_id } = req.params;
        
        const statsResult = await pool.query(`
            SELECT 
                COUNT(DISTINCT gs.player_id) as total_players,
                COUNT(gs.id) as total_sessions,
                COUNT(gs.id) FILTER (WHERE gs.session_status = 'completed') as completed_sessions,
                AVG(gs.final_score) FILTER (WHERE gs.session_status = 'completed') as avg_score,
                MAX(gs.final_score) as highest_score
            FROM neoquest.game_sessions gs
            WHERE gs.game_id = $1
        `, [game_id]);
        
        const stats = statsResult.rows[0] || {};
        
        res.json({
            success: true,
            game_id: parseInt(game_id),
            statistics: {
                total_players: parseInt(stats.total_players) || 0,
                total_sessions: parseInt(stats.total_sessions) || 0,
                completed_sessions: parseInt(stats.completed_sessions) || 0,
                completion_rate: stats.total_sessions > 0 ? 
                    ((stats.completed_sessions / stats.total_sessions) * 100).toFixed(1) : 0,
                average_score: stats.avg_score ? Math.round(stats.avg_score) : 0,
                highest_score: parseInt(stats.highest_score) || 0
            },
            generated_at: new Date()
        });
        
    } catch (error) {
        console.error('Stats error:', error);
        res.status(500).json({ 
            success: false, 
            error: 'Failed to retrieve statistics' 
        });
    }
});

// ===============================================
// ERROR HANDLING
// ===============================================

router.use((error, req, res, next) => {
    console.error('Level1 API Error:', error);
    
    if (error instanceof multer.MulterError) {
        if (error.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({
                success: false,
                error: 'Files too large. Maximum total size is 50MB.'
            });
        }
    }
    
    res.status(500).json({
        success: false,
        error: 'Internal server error'
    });
});

module.exports = router;