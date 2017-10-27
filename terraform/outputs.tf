output "elb_dns_name" {
  value = "${aws_elb.main.dns_name}"
}