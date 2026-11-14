/**
 * DEBUG: Services einzeln testen
 * Das Problem liegt wahrscheinlich in einem der importierten Services
 */

require('dotenv').config();
const express = require('express');
const path = require('path');

const app = express();
const PORT = 3000;

console.log('🔍 Testing services imports...');

// Basic middleware
app.use(express.json());
app.use('/media', express.static(path.join(__dirname, '../media')));
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Test routes
app.get('/', (req, res) => {
  res.json({ message: 'Testing services' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// Load routes (wir wissen, dass diese funktionieren)
const authRoutes = require('./routes/auth');
const gameRoutes = require('./routes/game');
const uploadRoutes = require('./routes/upload');
const adminRoutes = require('./routes/admin');
const esp32Routes = require('./routes/esp32');
const level1Routes = require('./routes/level1');
const missionRoutes = require('./routes/mission');
const sessionRoutes = require('./routes/game_session');

app.use('/api/auth', authRoutes);
app.use('/api/game', gameRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/esp32', esp32Routes);
app.use('/api/level1', level1Routes);
app.use('/api/mission', missionRoutes);
app.use('/api/session', sessionRoutes);

console.log('✅ All routes loaded successfully');

// JETZT teste die verdächtigen Services einzeln:

console.log('🧪 Testing service imports...');

// Test 1: Database Service
try {
  console.log('📊 Testing database service...');
  const { connectDB, testConnection } = require('./config/database');
  console.log('✅ Database service imported successfully');
  
  // ACHTUNG: Rufe testConnection() NICHT auf - das könnte das Problem sein!
  // await testConnection(); <- Das hier könnte crashen
  
} catch (error) {
  console.error('❌ Database service failed:', error.message);
}

// Test 2: Logger Service
try {
  console.log('📝 Testing logger service...');
  const logger = require('./utils/logger');
  console.log('✅ Logger service imported successfully');
  
  // Test logging
  logger.info('Logger test message');
  
} catch (error) {
  console.error('❌ Logger service failed:', error.message);
}

// Test 3: Security Middleware
try {
  console.log('🔒 Testing security middleware...');
  const { validateIPAccess } = require('./middleware/security');
  console.log('✅ Security middleware imported successfully');
} catch (error) {
  console.error('❌ Security middleware failed:', error.message);
}

// Test 4: Error Handler
try {
  console.log('⚠️ Testing error handler...');
  const { errorHandler } = require('./middleware/errorHandler');
  console.log('✅ Error handler imported successfully');
  
  // Add error handler
  app.use(errorHandler);
  
} catch (error) {
  console.error('❌ Error handler failed:', error.message);
}

// Wildcard route
app.all('/*catchall', (req, res) => {
  res.status(404).json({
    error: 'Not found',
    path: req.originalUrl
  });
});

console.log('🚀 Starting server with services...');

// VERDÄCHTIG: Der Server-Start könnte das Problem sein!
// Teste mit und ohne async/await

app.listen(PORT, () => {
  console.log('✅ Server running on port 3000');
  
  // HIER könnte das Problem liegen - async Database-Test beim Start:
  console.log('🧪 Testing database connection after server start...');
  
  // Das hier könnte das Problem verursachen:
  // testDatabaseConnection();
});

// Separate Funktion für DB-Test
async function testDatabaseConnection() {
  try {
    console.log('📊 Testing database connection...');
    const { testConnection } = require('./config/database');
    const dbStatus = await testConnection();
    console.log('✅ Database connection:', dbStatus ? 'OK' : 'Failed');
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
  }
}

// Teste DB-Verbindung separat (nach 1 Sekunde)
setTimeout(testDatabaseConnection, 1000);

module.exports = app;