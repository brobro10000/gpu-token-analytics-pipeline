// Runs automatically on first container start
const dbname = "ca0";
const db = db.getSiblingDB(dbname);

db.gpu_metrics.createIndex({ ts: 1 });
db.gpu_metrics.createIndex({ host: 1, gpu_index: 1 });

db.token_usage.createIndex({ ts: 1 });
db.token_usage.createIndex({ model: 1 });
