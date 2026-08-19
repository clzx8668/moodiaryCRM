//! 指数退避策略（架构文档 4.9 / 二次开发计划 P1.8：1s 起、最多重试 5 次）

use anyhow::{Result, anyhow};

/// 指数退避：delay(n) = min(initial * factor^(n-1), max_delay)
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ExponentialBackoff {
    initial_delay_ms: u64,
    factor: f64,
    max_delay_ms: u64,
    max_attempts: u32,
}

impl ExponentialBackoff {
    pub fn new(
        initial_delay_ms: u64,
        factor: f64,
        max_delay_ms: u64,
        max_attempts: u32,
    ) -> Result<Self> {
        if initial_delay_ms == 0 {
            return Err(anyhow!("initial_delay_ms 必须大于 0"));
        }
        if !factor.is_finite() || factor < 1.0 {
            return Err(anyhow!("factor 必须为 >= 1.0 的有限数"));
        }
        if max_delay_ms < initial_delay_ms {
            return Err(anyhow!("max_delay_ms 不能小于 initial_delay_ms"));
        }
        if max_attempts == 0 {
            return Err(anyhow!("max_attempts 必须大于 0"));
        }
        Ok(Self {
            initial_delay_ms,
            factor,
            max_delay_ms,
            max_attempts,
        })
    }

    /// P1.8 默认：1s 起、x2、上限 60s、最多重试 5 次
    pub fn default() -> Self {
        Self::new(1000, 2.0, 60_000, 5).expect("默认参数恒合法")
    }

    /// 第 `attempt` 次重试的等待时长（attempt 从 1 起）；超出上限返回 None
    pub fn delay_for(&self, attempt: u32) -> Option<u64> {
        if attempt == 0 || attempt > self.max_attempts {
            return None;
        }
        let mut delay = self.initial_delay_ms;
        for _ in 1..attempt {
            delay = ((delay as f64) * self.factor).round() as u64;
            if delay >= self.max_delay_ms {
                return Some(self.max_delay_ms);
            }
        }
        Some(delay.min(self.max_delay_ms))
    }

    pub fn should_retry(&self, attempt: u32) -> bool {
        attempt > 0 && attempt <= self.max_attempts
    }

    pub fn max_attempts(&self) -> u32 {
        self.max_attempts
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_delay_sequence() {
        let backoff = ExponentialBackoff::default();
        assert_eq!(backoff.delay_for(1), Some(1000));
        assert_eq!(backoff.delay_for(2), Some(2000));
        assert_eq!(backoff.delay_for(3), Some(4000));
        assert_eq!(backoff.delay_for(4), Some(8000));
        assert_eq!(backoff.delay_for(5), Some(16000));
        assert_eq!(backoff.delay_for(6), None);
    }

    #[test]
    fn delay_caps_at_max() {
        let backoff = ExponentialBackoff::new(1000, 2.0, 3000, 10).unwrap();
        assert_eq!(backoff.delay_for(1), Some(1000));
        assert_eq!(backoff.delay_for(2), Some(2000));
        assert_eq!(backoff.delay_for(3), Some(3000));
        assert_eq!(backoff.delay_for(4), Some(3000));
        assert_eq!(backoff.delay_for(10), Some(3000));
        assert_eq!(backoff.delay_for(11), None);
    }

    #[test]
    fn should_retry_bounds() {
        let backoff = ExponentialBackoff::default();
        assert!(backoff.should_retry(1));
        assert!(backoff.should_retry(5));
        assert!(!backoff.should_retry(0));
        assert!(!backoff.should_retry(6));
        assert_eq!(backoff.max_attempts(), 5);
    }

    #[test]
    fn invalid_parameters_rejected() {
        assert!(ExponentialBackoff::new(0, 2.0, 1000, 5).is_err());
        assert!(ExponentialBackoff::new(1000, 0.5, 1000, 5).is_err());
        assert!(ExponentialBackoff::new(1000, 2.0, 500, 5).is_err());
        assert!(ExponentialBackoff::new(1000, 2.0, 1000, 0).is_err());
        assert!(ExponentialBackoff::new(1000, f64::NAN, 1000, 5).is_err());
    }

    #[test]
    fn fractional_factor_rounds_up() {
        let backoff = ExponentialBackoff::new(1000, 1.5, 10_000, 5).unwrap();
        assert_eq!(backoff.delay_for(2), Some(1500));
        assert_eq!(backoff.delay_for(3), Some(2250));
    }
}
