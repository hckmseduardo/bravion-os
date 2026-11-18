#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Platform { pub deb: &'static str, pub download: &'static str }
pub fn platform(arch: &str) -> Result<Platform, String> {
    match arch {
        "aarch64" => Ok(Platform { deb: "arm64", download: "linux-arm64" }),
        "x86_64" => Ok(Platform { deb: "amd64", download: "linux-x64" }),
        _ => Err(format!("Unsupported Linux architecture: {arch}")),
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn amd64_downloads_are_not_arm64() {
        assert_eq!(platform("x86_64").unwrap(), Platform { deb: "amd64", download: "linux-x64" });
    }
    #[test] fn raspberry_pi_downloads_stay_arm64() {
        assert_eq!(platform("aarch64").unwrap(), Platform { deb: "arm64", download: "linux-arm64" });
    }
    #[test] fn unsupported_architecture_fails_before_downloading() {
        assert!(platform("riscv64").is_err());
    }
}
