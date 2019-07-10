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
    name = "flask_webapp_asg"
    min_size = 1
    max_size = 2
    launch_configuration = "${aws_launch_configuration.lc.name}"
    vpc_zone_identifier = [
        "${aws_subnet.subnet_a.id}",
        "${aws_subnet.subnet_b.id}",
    ]
}

/*
resource "aws_iam_role" "ecs_service_role" {
    name = "flask_ecs_service_role"
    path = "/"
}

resource "aws_iam_role_policy_attachment" "ecs_service_role_policy_attachment" {
    role = "${aws_iam_role.ecs_service_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}
*/

resource "aws_iam_role" "ecs_instance_role" {
    name = "flask_ecs_instance_role"
    path = "/"
    assume_role_policy = "${data.aws_iam_policy_document.ecs_instance_policy.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy_attachment" {
    role = "${aws_iam_role.ecs_instance_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

data "aws_iam_policy_document" "ecs_instance_policy" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

resource "aws_iam_instance_profile" "flask_instance_profile" {
    name = "flask_instance_profile"
    role = "${aws_iam_role.ecs_instance_role.name}"
}

resource "aws_launch_configuration" "lc" {
    name = "flask_webapp_lc"
    image_id = "ami-0c0c01a7a42f41c0c"
    instance_type = "t2.micro"
    key_name = "sallai-key"
    iam_instance_profile = "${aws_iam_instance_profile.flask_instance_profile.id}"
    user_data = <<EOF
        #!/bin/bash
        echo ECS_CLUSTER=flask_webapp_cluster >> /etc/ecs/ecs.config
EOF
}

resource "aws_s3_bucket" "bucket" {
    bucket = "sallai-demo-bucket"
}

resource "aws_ecr_repository" "ecr_repo" {
    name = "sallai-test"
}

output "ecr_url" {
    value ="${aws_ecr_repository.ecr_repo.repository_url}"
}

resource "aws_ecs_cluster" "cluster" {
    name = "flask_webapp_cluster"
}

resource "aws_ecs_service" "service" {
    name = "flask_webapp_service"
    cluster = "${aws_ecs_cluster.cluster.id}"
    task_definition = "${aws_ecs_task_definition.flask_webapp.arn}"
    desired_count = 3
}

resource "aws_ecs_task_definition" "flask_webapp" {
    family = "flask_webapp"
    container_definitions = <<EOF
    [
        {
            "name": "flask_webapp",
            "image": "464255417364.dkr.ecr.eu-central-1.amazonaws.com/sallai-test:0.0.1",
            "memory": 512,
            "cpu": 1,
            "essential": true,
            "portMappings": [
                {
                    "containerPort": 5000,
                    "hostPort": 5000
                }
            ]
        }
    ]
EOF
}
