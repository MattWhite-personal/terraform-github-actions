variable "runner-ip" {
  type        = string
  description = "IP address of the GitHub Actions runner"
  sensitive   = true
}