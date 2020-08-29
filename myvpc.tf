
provider "aws" {

        region = "ap-south-1"
        profile = "yogi"
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "main"
  }
}
resource "aws_subnet" "subnet1" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "public-subnet"
  }
}
resource "aws_subnet" "subnet2" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "private-subnet"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "myigw1"
  }
}

resource "aws_eip" "nat" {
  vpc              = true
}

resource "aws_nat_gateway" "ngw" {
   depends_on = [aws_internet_gateway.gw]  
allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet1.id
  
  tags = {
    Name = "Nat Gateway"
  }
}

resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "n" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.ngw.id}"
  }

  tags = {
    Name = "main"
  }
}



resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.r.id
}
resource "aws_route_table_association" "rn"{
    subnet_id = aws_subnet.subnet2.id
    route_table_id = aws_route_table.n.id
}




variable ssh_key_name {

        default = "yogitfkey"
}



resource "tls_private_key" "key-pair" {

        algorithm = "RSA"
        rsa_bits = 4096
}

resource "local_file" "private-key" {

    content = tls_private_key.key-pair.private_key_pem
    filename =  "${var.ssh_key_name}.pem"
    file_permission = "0400"
}

resource "aws_key_pair" "deployer" {

  key_name   = var.ssh_key_name
  public_key = tls_private_key.key-pair.public_key_openssh
}

resource "aws_security_group" "wordp" {

	name = "wordp"
	description = "Allow HTTP and SSH inbound traffic"
        vpc_id      =  "${aws_vpc.main.id}"
	
	ingress	{
		
		from_port = 80
      		to_port = 80
      		protocol = "tcp"
      		cidr_blocks = ["0.0.0.0/0"]
      		ipv6_cidr_blocks = ["::/0"]
      	}
          
 ingress { 
           description = "Mysql"
           from_port = 3306
           to_port = 3306
           protocol = "tcp"
           cidr_blocks = ["0.0.0.0/0"]
}
      	
      	ingress {
      		
      		from_port = 22
      		to_port = 22
      		protocol = "tcp"
      		cidr_blocks = ["0.0.0.0/0"]
      		ipv6_cidr_blocks = ["::/0"]
      	}
      	
      	ingress {
      		
      		from_port = -1
      		to_port = -1
      		protocol = "icmp"
      		cidr_blocks = ["0.0.0.0/0"]
      		ipv6_cidr_blocks = ["::/0"]
      	}
      	
      	egress {
      	
      		from_port = 0
      		to_port = 0
      		protocol = "-1"
      		cidr_blocks = ["0.0.0.0/0"]
      	}
}


resource "aws_instance" "web" {
  ami           = "ami-02d55cb47e83a99a0"
  instance_type = "t2.micro"
  key_name = "${var.ssh_key_name}"
  subnet_id = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.wordp.id]
  availability_zone = "ap-south-1a"
  associate_public_ip_address = true
 



  tags = {
    Name = "myserver"
  }

}



resource "aws_security_group" "bastion_grp" {
name = "bashion_grp"
description = "allow ssh for bashion host"
vpc_id      =  "${aws_vpc.main.id}"


ingress {
           description = "TCP"
           from_port = 22
           to_port = 22
           protocol = "tcp"
           cidr_blocks = ["0.0.0.0/0"]
}

 egress {

           from_port = 0
           to_port = 0
           protocol = "-1"
           cidr_blocks = ["0.0.0.0/0"]
       }
  tags = {
            Name = "sec_grp"
          }
 }


resource "aws_security_group" "sec_grp_sql" {
name = "sec_grp_sql"
description = "allow mysql and ssh"
vpc_id      =  "${aws_vpc.main.id}"


ingress {
           description = "TCP"
           from_port = 3306
           to_port = 3306
           protocol = "tcp"
           cidr_blocks = ["0.0.0.0/0"]
}
ingress {
      		
      		from_port = 22
      		to_port = 22
      		protocol = "tcp"
      		cidr_blocks = ["0.0.0.0/0"]
      		ipv6_cidr_blocks = ["::/0"]
      	}

 egress {

           from_port = 0
           to_port = 0
           protocol = "-1"
           cidr_blocks = ["0.0.0.0/0"]
       }
  tags = {
            Name = "sec_grp_sql"
          }
 }
 
 
 resource "aws_instance" "bastion" {
  ami="ami-0ebc1ac48dfd14136"
  instance_type = "t2.micro"
  key_name = "${var.ssh_key_name}"
  subnet_id = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.bastion_grp.id]
   availability_zone = "ap-south-1a"
  associate_public_ip_address = true

 tags = {
        Name = "yogi_bastion_host"


        }
}
output "mybastionhost" {
          value = aws_instance.bastion.private_ip
  }
 
resource "aws_instance" "os2" {
  ami="ami-00adede95127e30d7"
  instance_type = "t2.micro"
  key_name = "${var.ssh_key_name}"
  subnet_id = aws_subnet.subnet2.id
  vpc_security_group_ids = [aws_security_group.sec_grp_sql.id,aws_security_group.bastion_grp.id]
  availability_zone = "ap-south-1a"
  user_data = <<-EOF
              #!/bin/bash
              docker run -dit -e MYSQL_ROOT_PASSWORD=redhat -p 3306:3306 mysql:5.7
              EOF

 tags = {
        Name = "mysql"


        }
}
output "mysql" {
          value = aws_instance.os2.private_ip
  }


 resource "null_resource" "nullremote4"  {

        depends_on = [
            aws_instance.os2,
          ]


          connection { 
            type     = "ssh"
            user     = "ubuntu"
            private_key = file("${var.ssh_key_name}.pem")
            host     = aws_instance.web.public_ip
          }

        provisioner "remote-exec" {
            inline = [
              "sudo apt-get update -y",
              "sudo apt-get install docker.io -y",
              "sudo docker pull wordpress",
              "sudo docker run -dit -e WORDPRESS_DB_HOST=${aws_instance.os2.private_ip} -e WORDPRESS_DB_USER=root -e WORDPRESS_DB_PASSWORD=redhat -e WORDPRESS_DB_NAME=mywordpress -p 80:80 wordpress"
            ]
          }
 provisioner "local-exec" {
            command = "firefox  ${aws_instance.web.public_ip}"
        }

        }



