const express = require("express");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json());

let tasks = [];

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "OK" });
});

// Upload task
app.post("/tasks", (req, res) => {
  console.log("Request received");
  const task = req.body;

  console.log("📥 Received:", task);

  const { id, title, type, payload } = task;

  if (!id || !title || !type || !payload) {
    console.log("❌ Invalid request: Missing required fields");
    return res.status(400).json({ error: "Missing required fields: id, title, type, and payload are required" });
  }

  tasks.push(task);

  console.log("✅ Task stored successfully");
  return res.status(200).json({ success: true, message: "Task stored successfully" });
});

// View tasks (debug)
app.get("/tasks", (req, res) => {
  res.json(tasks);
});

app.listen(3000, "0.0.0.0", () => {
  console.log("🚀 Server running on port 3000");
});