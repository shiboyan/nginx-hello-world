provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags {
    Name = "nginx-hello-world"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "nginx-hello-world-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "nginx-hello-world-public"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}

resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags {
    Name = "nginx-hello-world-public"
  }
}

resource "aws_eip" "public" {
  vpc = true
}

resource "aws_eip_association" "public_web" {
  instance_id   = "${aws_instance.web.id}"
  allocation_id = "${aws_eip.public.id}"
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_security_group" "web_host_sg" {
  name        = "web_host"
  description = "Allow HTTP to web hosts from everywhere"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "nginx-hello-world" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["centos-7-nginx-hello-world*"]
  }
}

resource "aws_instance" "web" {
  ami           = "${data.aws_ami.nginx-hello-world.id}"
  instance_type = "t2.micro"
  subnet_id     = "${aws_subnet.public.id}"

  vpc_security_group_ids = [
    "${aws_security_group.web_host_sg.id}",
  ]

  tags {
    Name = "nginx-hello-world-web"
  }
}

resource "aws_iam_server_certificate" "test_cert" {
  name_prefix      = "example-cert"
  certificate_body = "${file("certs/cert.pem")}"
  private_key      = "${file("certs/key.pem")}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "main" {
  name            = "hello-world-nginx-elb"
  subnets         = ["${aws_subnet.public.id}"]
  instances       = ["${aws_instance.web.id}"]
  security_groups = ["${aws_security_group.web_host_sg.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port      = 80
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "${aws_iam_server_certificate.test_cert.arn}"
  }
}
