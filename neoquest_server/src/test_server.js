/**
 * MINIMAL SERVER TEST
 * Aktiviere Routen einzeln um den Übeltäter zu finden
 */

require('dotenv').config();
const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;

// Basic middleware
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.json({ message: 'Minimal test server' });
});

console.log('🧪 Testing route imports one by one...');

// Test 1: Nur authRoutes
try {
  const authRoutes = require('./routes/auth');
  app.use('/api/auth', authRoutes);
  console.log('✅ authRoutes loaded and registered');
} catch (error) {
  console.error('❌ authRoutes failed:', error.message);
}

// Test 2: gameRoutes hinzufügen
try {
  const gameRoutes = require('./routes/game');
  app.use('/api/game', gameRoutes);
  console.log('✅ gameRoutes loaded and registered');
} catch (error) {
  console.error('❌ gameRoutes failed:', error.message);
}

// Test 3: uploadRoutes hinzufügen
try {
  const uploadRoutes = require('./routes/upload');
  app.use('/api/upload', uploadRoutes);
  console.log('✅ uploadRoutes loaded and registered');
} catch (error) {
  console.error('❌ uploadRoutes failed:', error.message);
}

// Test 4: adminRoutes hinzufügen
try {
  const adminRoutes = require('./routes/admin');
  app.use('/api/admin', adminRoutes);
  console.log('✅ adminRoutes loaded and registered');
} catch (error) {
  console.error('❌ adminRoutes failed:', error.message);
}

// Test 5: esp32Routes hinzufügen
try {
  const esp32Routes = require('./routes/esp32');
  app.use('/api/esp32', esp32Routes);
  console.log('✅ esp32Routes loaded and registered');
} catch (error) {
  console.error('❌ esp32Routes failed:', error.message);
}

// Test 6: missionRoutes hinzufügen
try {
  const missionRoutes = require('./routes/mission');
  app.use('/api/mission', missionRoutes);
  console.log('✅ missionRoutes loaded and registered');
} catch (error) {
  console.error('❌ missionRoutes failed:', error.message);
}

// Test 7: sessionRoutes hinzufügen
try {
  const sessionRoutes = require('./routes/game_session');
  app.use('/api/session', sessionRoutes);
  console.log('✅ sessionRoutes loaded and registered');
} catch (error) {
  console.error('❌ sessionRoutes failed:', error.message);
}

// Test 8: level1Routes hinzufügen (VERDÄCHTIG!)
// try {
//   const level1Routes = require('./routes/level1');
//   app.use('/api/level1', level1Routes);
//   console.log('✅ level1Routes loaded and registered');
// } catch (error) {
//   console.error('❌ level1Routes failed:', error.message);
// }

// 404 handler (Express 5.x compatible)
app.all('/*catchall', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.originalUrl,
    method: req.method
  });
});

// Start server
console.log('🚀 Starting minimal server...');
app.listen(PORT, () => {
  console.log(`✅ Server running on port ${PORT}`);
  console.log('📍 Test endpoints:');
  console.log(`   http://localhost:${PORT}/health`);
  console.log(`   http://localhost:${PORT}/api/auth/verify`);
  console.log(`   http://localhost:${PORT}/api/game/test`);
});

module.exports = app;