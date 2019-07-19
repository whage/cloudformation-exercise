resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name = "flask-vpc"
    }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_subnet" "pub_subnet_a" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.0.0/24"
    availability_zone = "eu-central-1a"

    tags = {
        Name = "flask-pub-subnet-a"
    }
}

resource "aws_subnet" "pub_subnet_b" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-central-1b"

    tags = {
        Name = "flask-pub-subnet-b"
    }
}

resource "aws_route_table" "pub_rt" {
    vpc_id = "${aws_vpc.vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.igw.id}"
    }

    tags = {
        Name = "flask-pub-route-table"
    }
}

resource "aws_route_table_association" "rta_pub_a" {
    subnet_id = "${aws_subnet.pub_subnet_a.id}"
    route_table_id = "${aws_route_table.pub_rt.id}"
}

resource "aws_route_table_association" "rta_pub_b" {
    subnet_id = "${aws_subnet.pub_subnet_b.id}"
    route_table_id = "${aws_route_table.pub_rt.id}"
}

resource "aws_eip" "nat" {
    vpc = true
    tags = {
        Name = "flask-webapp-test-eip"
    }
}

resource "aws_nat_gateway" "ngw" {
    allocation_id = "${aws_eip.nat.id}"
    subnet_id = "${aws_subnet.pub_subnet_a.id}"
    depends_on = ["aws_internet_gateway.igw"]
}

resource "aws_subnet" "priv_subnet_a" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.2.0/24"
    availability_zone = "eu-central-1a"

    tags = {
        Name = "flask-priv-subnet-a"
    }
}

resource "aws_subnet" "priv_subnet_b" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.3.0/24"
    availability_zone = "eu-central-1b"

    tags = {
        Name = "flask-priv-subnet-b"
    }
}

resource "aws_route_table" "priv_rt" {
    vpc_id = "${aws_vpc.vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_nat_gateway.ngw.id}"
    }

    tags = {
        Name = "flask-priv-route-table"
    }
}

resource "aws_route_table_association" "rta_priv_a" {
    subnet_id = "${aws_subnet.priv_subnet_a.id}"
    route_table_id = "${aws_route_table.priv_rt.id}"
}

resource "aws_route_table_association" "rta_priv_b" {
    subnet_id = "${aws_subnet.priv_subnet_b.id}"
    route_table_id = "${aws_route_table.priv_rt.id}"
}

resource "aws_db_subnet_group" "subnet_group" {
    name = "test-subnet-group"
    subnet_ids = [
        "${aws_subnet.priv_subnet_a.id}",
        "${aws_subnet.priv_subnet_b.id}",
    ]
}

resource "aws_security_group" "db_sg" {
    name = "flask-rds-sg"
    vpc_id = "${aws_vpc.vpc.id}"
    
    ingress {
        from_port = 0
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
    }
}

resource "aws_security_group" "ecs_sg" {
    name = "flask-ecs-sg"
    vpc_id = "${aws_vpc.vpc.id}"
    
    ingress {
        from_port = 32768
        to_port = 60999
        protocol = "tcp"
        /*security_groups = [
            "${aws_security_group.lb_sg.id}"
        ]*/
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
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
    vpc_security_group_ids = ["${aws_security_group.db_sg.id}"]
    multi_az = true
}

resource "aws_iam_role" "ecs_service_role" {
    name = "flask_ecs_service_role"
    path = "/"
    assume_role_policy = "${data.aws_iam_policy_document.ecs_service_policy.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_service_role_policy_attachment" {
    role = "${aws_iam_role.ecs_service_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "ecs_service_policy" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type = "Service"
            identifiers = ["ecs.amazonaws.com"]
        }
    }
}

resource "aws_iam_role" "ecs_instance_role" {
    name = "flask_ecs_instance_role"
    path = "/"
    assume_role_policy = "${data.aws_iam_policy_document.ecs_instance_policy.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy_attachment" {
    role = "${aws_iam_role.ecs_instance_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_ssm_instance_role_policy_attachment" {
    role = "${aws_iam_role.ecs_instance_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
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

resource "aws_autoscaling_group" "asg" {
    name = "flask_webapp_asg"
    min_size = 1
    max_size = 2
    launch_configuration = "${aws_launch_configuration.lc.name}"
    vpc_zone_identifier = [
        "${aws_subnet.priv_subnet_a.id}",
        "${aws_subnet.priv_subnet_b.id}",
    ]

    tag {
        key = "Name"
        value = "sallai_flask_webapp_asg"
        propagate_at_launch = true
    }
}

resource "aws_launch_configuration" "lc" {
    name = "flask_webapp_lc"
    image_id = "ami-0650e7d86452db33b" # amzn2-ami-ecs-hvm-2.0.20190709-x86_64-ebs
    instance_type = "t2.medium"
    key_name = "sallai-key"
    iam_instance_profile = "${aws_iam_instance_profile.flask_instance_profile.id}"
    security_groups = [
        "${aws_security_group.ecs_sg.id}"
    ]
    user_data = <<EOF
        #!/bin/bash
        mkdir /etc/ecs
        echo ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config
        sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
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
    iam_role = "${aws_iam_role.ecs_service_role.name}"

    depends_on = [
        "aws_lb_listener.listener"
    ]

    load_balancer {
        target_group_arn = "${aws_lb_target_group.lb_tg.arn}"
        container_name = "flask_webapp"
        container_port = 5000
    }
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
                    "hostPort": 0
                }
            ]
        }
    ]
EOF
}

resource "aws_lb" "flask_webapp_load_balancer" {
    name = "flask-webapp-load-balancer"
    internal = false
    load_balancer_type = "application"
    security_groups = [
        "${aws_security_group.lb_sg.id}"
    ]
    subnets = [
        "${aws_subnet.pub_subnet_a.id}",
        "${aws_subnet.pub_subnet_b.id}",
    ]
    depends_on = [
        "aws_internet_gateway.igw"
    ]
}

resource "aws_security_group" "lb_sg" {
    name = "flask-lb-sg"
    vpc_id = "${aws_vpc.vpc.id}"
    
    ingress {
        from_port = 0
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_lb_target_group" "lb_tg" {
    name = "flask-webapp-tg"
    port = "80"
    protocol = "HTTP"
    vpc_id = "${aws_vpc.vpc.id}"

    depends_on = [
        "aws_lb.flask_webapp_load_balancer"
    ]
}

resource "aws_lb_listener" "listener" {
    load_balancer_arn = "${aws_lb.flask_webapp_load_balancer.arn}"
    port = "80"
    protocol = "HTTP"

    default_action {
        target_group_arn = "${aws_lb_target_group.lb_tg.arn}"
        type = "forward"
    }
}

resource "aws_route53_record" "dns_record" {
  zone_id = "Z1D53ICGMBP5SW"
  name    = "flask"
  type    = "A"

  alias {
    name = "${aws_lb.flask_webapp_load_balancer.dns_name}"
    zone_id = "Z215JYRZR1TBD5"
    evaluate_target_health = true
  }
}
