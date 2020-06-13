//variable created to store the region
variable "region" {
  default = "ap-south-1"
}

//variable created to store the key
variable "key" {
  default = "My12"
}

//provider and profile
provider "aws" {
  region	= var.region
  profile	= "mymanali"
}

//generate key-pair
resource "aws_key_pair" "enter_key_name" {
  key_name   = var.key
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+nYcXP3F5MRp+1XLRCoOd5YnC58uYrfKNnVJ5KNexZJU5J4qScYk+htJQCvUVTON/3X29zLM3pcRERkRy7dr8pv0L//MdL+n4nf7hI9qh/sAl7cTSx/sw+R7Do25NNDTZzksmHNK+9ojwus+C2DI+KQ/LLiGR/r6TNdsPPSeJLN0gxdbM2jaH9mGoOlQdPC5eJBYkA36Rk2AHWQ9S9Acjz1h19rxorLKV95UN3T09MJsaTwlOosf0h8UU7lBmdIya5QN18XmPy6XovaNxJlNLFQwSbVukR5RE/W6eeg/P2wbq6sHuKi3NYWJXAuj71RWCIWFVY8P8XZ3ZBdnoOF9b manali@DESKTOP-B1P0RR5"
}


//security groups
resource "aws_security_group" "ingress_all_test" {
name = "allow-all-sg"

ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
from_port = 22
    to_port = 22
    protocol = "tcp"
  }
ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
from_port = 0
    to_port = 80
    protocol = "tcp"
  }
// Terraform removes the default rule
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
   
 }
}

//create instance
resource "aws_instance" "web1" {
  key_name      = aws_key_pair.enter_key_name.key_name
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.ingress_all_test.name}"]
  
 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Manali Jain/Desktop/key/keyfolder/My12.pem")
    host     = aws_instance.web1.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }


tags = {
    Name = "terraform"
  }
}

//download images from github
resource "null_resource" "image" {
  provisioner "local-exec" {
    command = "git clone https://github.com/manali1230/images.git images"
  }
}

//creating EBS Volume of size 1
resource "aws_ebs_volume" "ebs_vol" {
  availability_zone = aws_instance.web1.availability_zone
  size              = 1

  tags = {
    Name = "tera_ebs"
  }
}

//Attach EBS Volume to the instance
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.ebs_vol.id
  instance_id = aws_instance.web1.id
  force_detach = true
}

output "op" {
	value = aws_instance.web1

}

//copied the IP to a .txt file
resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web1.public_ip} > publicip.txt"
  	}
}




//make s3 bucket
resource "aws_s3_bucket" "b" {
  bucket = "manali12"
  acl = "public-read"
 
  tags = {
    Name  = "My-bucky-dgsjkh"
    Environment = "Dev"
  }
}
//bucket object
resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.b.bucket
  acl = "public-read"
  key    = "open.png"
  source = "images/open.png"
depends_on=[aws_s3_bucket.b,null_resource.image]

}

//make cloudfront distribution
resource "aws_cloudfront_distribution" "prod_distribution" {
    origin {
         domain_name = "${aws_s3_bucket.b.bucket_regional_domain_name}"
         origin_id   = "${aws_s3_bucket.b.id}"
 
        custom_origin_config {
            http_port = 80
            https_port = 443
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }
    # By default, show index.html file
    default_root_object = "index.html"
    enabled = true
    # If there is a 404, return index.html with a HTTP 200 Response
    custom_error_response {
        error_caching_min_ttl = 3000
        error_code = 404
        response_code = 200
        response_page_path = "/index.html"
    }

default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.b.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE","IN"]
    }
  }

    # SSL certificate for the service.
    viewer_certificate {
        cloudfront_default_certificate = true
    }
 depends_on=[aws_s3_bucket.b]
}

resource "null_resource" "nullremote"  {
depends_on = [  aws_volume_attachment.ebs_att,aws_cloudfront_distribution.prod_distribution]
    connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.web1.public_ip
        port    = 22
        private_key = file("C:/Users/Manali Jain/Desktop/key/keyfolder/My12.pem")
    }
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att
  ]
 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Manali Jain/Desktop/key/keyfolder/My12.pem")
    host     = aws_instance.web1.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/manali1230/images.git /var/www/html/",
      "sudo su << EOF",
            "echo \"${aws_cloudfront_distribution.prod_distribution.domain_name}\" >> /var/www/html/path.txt",
            "EOF",
      "sudo systemctl restart httpd"
    ]
  }
}


//open the website in chrome
resource "null_resource" "nulllocal1"  {
depends_on = [
    null_resource.nullremote3,
  ]
	provisioner "local-exec" {
	    command = "chrome  ${aws_instance.web1.public_ip}"
  	}
}
