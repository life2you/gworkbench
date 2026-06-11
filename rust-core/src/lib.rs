use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppCapability {
    pub name: String,
    pub status: String,
}

pub fn planned_capabilities() -> Vec<AppCapability> {
    vec![
        AppCapability {
            name: "worktrees".to_string(),
            status: "planned".to_string(),
        },
        AppCapability {
            name: "merge_requests".to_string(),
            status: "planned".to_string(),
        },
        AppCapability {
            name: "settings".to_string(),
            status: "planned".to_string(),
        },
    ]
}

#[cfg(test)]
mod tests {
    use super::planned_capabilities;

    #[test]
    fn exposes_initial_capabilities() {
        let capabilities = planned_capabilities();
        assert_eq!(capabilities.len(), 3);
    }
}
