//! 结构化 JSON 同步日志（架构文档 4.8）
//!
//! 格式：每行一个 JSON 对象，字段 timestamp/level/operation/target/detail/error。
//! 设置页可读取最近 500 条并按级别/时间筛选（P1.10 由 Flutter 端实现）。

use crate::sync::now_millis;
use anyhow::{Result, anyhow};
use serde::{Deserialize, Serialize};
use std::fmt;
use std::fs::{OpenOptions, create_dir_all};
use std::io::Write;
use std::path::PathBuf;
use std::sync::Mutex;

/// 日志级别
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LogLevel {
    Info,
    Warn,
    Error,
}

impl fmt::Display for LogLevel {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            LogLevel::Info => "INFO",
            LogLevel::Warn => "WARN",
            LogLevel::Error => "ERROR",
        };
        f.write_str(s)
    }
}

/// 日志操作类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LogOperation {
    Pull,
    Push,
    Upload,
    Download,
    Sync,
    Other,
}

impl fmt::Display for LogOperation {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            LogOperation::Pull => "pull",
            LogOperation::Push => "push",
            LogOperation::Upload => "upload",
            LogOperation::Download => "download",
            LogOperation::Sync => "sync",
            LogOperation::Other => "other",
        };
        f.write_str(s)
    }
}

/// 日志目标
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LogTarget {
    Diary,
    Block,
    File,
    Crm,
    Vector,
    Other,
}

impl fmt::Display for LogTarget {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            LogTarget::Diary => "diary",
            LogTarget::Block => "block",
            LogTarget::File => "file",
            LogTarget::Crm => "crm",
            LogTarget::Vector => "vector",
            LogTarget::Other => "other",
        };
        f.write_str(s)
    }
}

/// 单条同步日志（JSON Lines 一行）
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SyncLogEntry {
    pub timestamp: i64,
    pub level: LogLevel,
    pub operation: LogOperation,
    pub target: LogTarget,
    pub detail: String,
    pub error: Option<String>,
}

impl SyncLogEntry {
    pub fn new(
        level: LogLevel,
        operation: LogOperation,
        target: LogTarget,
        detail: impl Into<String>,
    ) -> Self {
        Self {
            timestamp: now_millis(),
            level,
            operation,
            target,
            detail: detail.into(),
            error: None,
        }
    }

    pub fn with_error(mut self, error: impl Into<String>) -> Self {
        self.error = Some(error.into());
        self
    }
}

/// 同步日志抽象（测试/事件总线可注入内存实现）
pub trait SyncLogger: Send + Sync {
    fn log(&self, entry: SyncLogEntry) -> Result<()>;
}

/// 追加写入 logs/sync.log 的 JSON Lines 实现
#[derive(Debug)]
pub struct JsonFileLogger {
    path: Mutex<PathBuf>,
}

impl JsonFileLogger {
    pub fn new(path: impl Into<PathBuf>) -> Self {
        Self {
            path: Mutex::new(path.into()),
        }
    }
}

impl SyncLogger for JsonFileLogger {
    fn log(&self, entry: SyncLogEntry) -> Result<()> {
        let path = self
            .path
            .lock()
            .map_err(|_| anyhow!("日志路径锁中毒"))?
            .clone();
        if let Some(parent) = path.parent() {
            create_dir_all(parent).map_err(|e| anyhow!("创建日志目录失败: {e}"))?;
        }
        let line = serde_json::to_string(&entry).map_err(|e| anyhow!("日志序列化失败: {e}"))?;
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&path)
            .map_err(|e| anyhow!("打开日志文件失败: {e}"))?;
        writeln!(file, "{line}").map_err(|e| anyhow!("写入日志失败: {e}"))
    }
}

/// 内存日志实现（测试 / 后续事件总线）
#[derive(Debug, Default)]
pub struct MemoryLogger {
    entries: Mutex<Vec<SyncLogEntry>>,
}

impl MemoryLogger {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn entries(&self) -> Vec<SyncLogEntry> {
        self.entries.lock().map(|g| g.clone()).unwrap_or_default()
    }

    pub fn count(&self, level: LogLevel) -> usize {
        self.entries().iter().filter(|e| e.level == level).count()
    }

    pub fn clear(&self) {
        if let Ok(mut guard) = self.entries.lock() {
            guard.clear();
        }
    }
}

impl SyncLogger for MemoryLogger {
    fn log(&self, entry: SyncLogEntry) -> Result<()> {
        self.entries
            .lock()
            .map_err(|_| anyhow!("内存日志锁中毒"))?
            .push(entry);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sync::now_millis;
    use std::fs;

    fn entry(level: LogLevel) -> SyncLogEntry {
        SyncLogEntry::new(level, LogOperation::Pull, LogTarget::Diary, "拉取日记变更")
            .with_error("连接超时")
    }

    #[test]
    fn memory_logger_records_and_counts() {
        let logger = MemoryLogger::new();
        logger.log(entry(LogLevel::Info)).unwrap();
        logger.log(entry(LogLevel::Warn)).unwrap();
        logger.log(entry(LogLevel::Error)).unwrap();
        assert_eq!(logger.entries().len(), 3);
        assert_eq!(logger.count(LogLevel::Info), 1);
        assert_eq!(logger.count(LogLevel::Error), 1);
        logger.clear();
        assert!(logger.entries().is_empty());
    }

    #[test]
    fn json_file_logger_writes_valid_json_lines() {
        let path = std::env::temp_dir().join(format!("moodiary_sync_log_{}.log", now_millis()));
        let logger = JsonFileLogger::new(path.as_path());
        logger.log(entry(LogLevel::Info)).unwrap();
        logger.log(entry(LogLevel::Error)).unwrap();

        let raw = fs::read_to_string(&path).expect("读取日志失败");
        let lines: Vec<&str> = raw.lines().collect();
        assert_eq!(lines.len(), 2);
        for line in lines {
            let parsed: serde_json::Value = serde_json::from_str(line).expect("日志行非法 JSON");
            assert!(parsed.get("timestamp").is_some());
            assert!(parsed.get("level").is_some());
            assert!(parsed.get("operation").is_some());
            assert!(parsed.get("target").is_some());
            assert!(parsed.get("detail").is_some());
            assert!(parsed.get("error").is_some());
        }

        fs::remove_file(&path).ok();
    }

    #[test]
    fn level_display_matches_uppercase() {
        assert_eq!(LogLevel::Info.to_string(), "INFO");
        assert_eq!(LogLevel::Warn.to_string(), "WARN");
        assert_eq!(LogLevel::Error.to_string(), "ERROR");
    }
}
