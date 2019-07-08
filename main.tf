resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet_a" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.0.0/24"
    availability_zone = "eu-central-1a"
}

resource "aws_subnet" "subnet_b" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-central-1b"
}

resource "aws_db_subnet_group" "subnet_group" {
    name = "test-subnet-group"
    subnet_ids = [
        "${aws_subnet.subnet_a.id}",
        "${aws_subnet.subnet_b.id}",
    ]
}

resource "aws_security_group" "sg" {
    name = "rds-test-sg"
    vpc_id = "${aws_vpc.vpc.id}"
    
    ingress {
        from_port = 0
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
    }
}

resource "aws_db_instance" "instance" {
    allocated_storage = 5
    storage_type = "gp2"
    engine = "mysql"
    instance_class = "db.t2.micro"
    identifier = "test-instance"
    name = "testdb" # name of the (mysql) database
    username = "username1234"
    password = "password1234"
    db_subnet_group_name = "${aws_db_subnet_group.subnet_group.name}"
    skip_final_snapshot = true
    vpc_security_group_ids = ["${aws_security_group.sg.id}"]
    multi_az = true
}

resource "aws_autoscaling_group" "asg" {
    name = "demo-asg"
    min_size = 1
    max_size = 2
    launch_configuration = "${aws_launch_configuration.lc.name}"
    vpc_zone_identifier = [
        "${aws_subnet.subnet_a.id}",
        "${aws_subnet.subnet_b.id}",
    ]
}

resource "aws_launch_configuration" "lc" {
    name = "demo-lc"
    image_id = "ami-0c0c01a7a42f41c0c"
    instance_type = "t2.micro"
}

resource "aws_s3_bucket" "bucket" {
    bucket = "sallai-demo-bucket"
}
