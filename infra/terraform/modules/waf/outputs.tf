output "web_acl_arn" {
  description = "The ARN of the WAF Web ACL to attach to the ALB via Ingress annotations"
  value       = aws_wafv2_web_acl.this.arn
}
