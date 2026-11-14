/**
*  Database Configuration and Connection Pool
* PostgreSQL connection management for NeoQuest
*/

const { Pool } = require('pg');
const logger = require('../utils/logger');

// Database configuration
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'neoquest',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
  
  // Connection pool settings
  max: 20,                    // Maximum number of clients
  idleTimeoutMillis: 30000,   // Close idle clients after 30 seconds
  connectionTimeoutMillis: 2000, // Return error after 2 seconds if connection could not be established
  
  // Schema setting for queries
  options: process.env.DB_SCHEMA ? `-c search_path=${process.env.DB_SCHEMA},public` : undefined
};

// Create connection pool
const pool = new Pool(dbConfig);

// Pool error handling
pool.on('error', (err, client) => {
  logger.error('Unexpected error on idle client:', err);
  process.exit(-1);
});

pool.on('connect', () => {
  logger.debug('Database client connected');
});

pool.on('remove', () => {
  logger.debug('Database client removed');
});

/**
 * Test database connection
 * @returns {Promise<boolean>} True if connection successful
 */
async function testConnection() {
  try {
    const client = await pool.connect();
    
    // Test query
    const result = await client.query('SELECT NOW() as current_time, version() as db_version');
    
    logger.info('Database connection test successful:', {
      time: result.rows[0].current_time,
      version: result.rows[0].db_version.split(' ')[0] // Just PostgreSQL version
    });
    
    client.release();
    return true;
    
  } catch (error) {
    logger.error('Database connection test failed:', error.message);
    return false;
  }
}

/**
 * Execute a query with parameters
 * @param {string} text SQL query text
 * @param {Array} params Query parameters
 * @returns {Promise<Object>} Query result
 */
async function query(text, params = []) {
  const start = Date.now();
  
  try {
    const result = await pool.query(text, params);
    const duration = Date.now() - start;
    
    logger.debug('Executed query', {
      text: text.substring(0, 100) + (text.length > 100 ? '...' : ''),
      duration: `${duration}ms`,
      rows: result.rowCount
    });
    
    return result;
    
  } catch (error) {
    const duration = Date.now() - start;
    
    logger.error('Query error', {
      text: text.substring(0, 100) + (text.length > 100 ? '...' : ''),
      error: error.message,
      duration: `${duration}ms`,
      params: params
    });
    
    throw error;
  }
}

/**
 * Get a client from the pool for transactions
 * @returns {Promise<Object>} Database client
 */
async function getClient() {
  try {
    const client = await pool.connect();
    
    // Add query method to client for consistency
    const originalQuery = client.query.bind(client);
    client.query = async (text, params) => {
      const start = Date.now();
      try {
        const result = await originalQuery(text, params);
        const duration = Date.now() - start;
        
        logger.debug('Client query executed', {
          text: text.substring(0, 100) + (text.length > 100 ? '...' : ''),
          duration: `${duration}ms`,
          rows: result.rowCount
        });
        
        return result;
      } catch (error) {
        const duration = Date.now() - start;
        logger.error('Client query error', {
          text: text.substring(0, 100) + (text.length > 100 ? '...' : ''),
          error: error.message,
          duration: `${duration}ms`
        });
        throw error;
      }
    };
    
    return client;
    
  } catch (error) {
    logger.error('Failed to get database client:', error);
    throw error;
  }
}

/**
 * Execute queries within a transaction
 * @param {Function} callback Function that receives client and executes queries
 * @returns {Promise<any>} Result of callback function
 */
async function transaction(callback) {
  const client = await getClient();
  
  try {
    await client.query('BEGIN');
    
    const result = await callback(client);
    
    await client.query('COMMIT');
    
    logger.debug('Transaction committed successfully');
    return result;
    
  } catch (error) {
    await client.query('ROLLBACK');
    
    logger.error('Transaction rolled back due to error:', error);
    throw error;
    
  } finally {
    client.release();
  }
}

/**
 * Build schema-prefixed table name
 * @param {string} tableName Table name without schema
 * @returns {string} Schema-prefixed table name
 */
function getTableName(tableName) {
  const schema = process.env.DB_SCHEMA || 'neoquest';
  return `${schema}.${tableName}`;
}

/**
 * Close all database connections
 */
async function closePool() {
  try {
    await pool.end();
    logger.info('Database pool closed');
  } catch (error) {
    logger.error('Error closing database pool:', error);
  }
}

// Graceful shutdown
process.on('SIGTERM', closePool);
process.on('SIGINT', closePool);

module.exports = {
  pool,
  query,
  getClient,
  transaction,
  testConnection,
  getTableName,
  closePool
};