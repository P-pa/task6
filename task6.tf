provider "aws"{
     region="ap-south-1"
     profile="pagarwal"
}




resource "aws_security_group" "aws_rds" {
     name        = "aws_rds"
     description = "rds"
     ingress {
          from_port   = 3306
          to_port     = 3306
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
     }
     egress {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
     }
     tags = {
          Name = "rds"
     }
}








resource "aws_db_instance" "wp_rds" {
     allocated_storage    = 20
     storage_type         = "gp2"
     identifier           = "wordpress-db"
     engine               = "mysql"
     engine_version       = "5.7.21"
     instance_class       = "db.t2.micro"
     name                 = "wprds"
     username             = "pratishtha"
     password             = "pratishtha138"
     port                 = 3306
     parameter_group_name = "default.mysql5.7"
     vpc_security_group_ids = [aws_security_group.aws_rds.id]
     publicly_accessible  = true
     skip_final_snapshot  = true
     depends_on=[aws_security_group.aws_rds]
}








provider "kubernetes"{
    
}


resource "kubernetes_persistent_volume_claim" "pvc_wp" {
	depends_on = [aws_db_instance.wp_rds]
	metadata {
		name   = "pvc-wp"
		labels = {
		env     = "Production"
		Country = "India" 
		}
	}

	wait_until_bound = false
	spec {
		access_modes = ["ReadWriteOnce"]
		resources {
			requests = {
			storage = "5Gi"
			}
		}
	}
}

resource "kubernetes_deployment" "wp-deploy"{
     metadata{
          name="wp-deploy"
     }
     depends_on = [kubernetes_persistent_volume_claim.pvc_wp]
     spec{
          replicas=1
               selector{
                    match_labels={
                         env="prod"
                         region="IN"
                         pod="wp-deploy"
                    }
                }
         template{
              metadata {
                   labels={
                        env="prod"
                        region="IN"
                        pod="wp-deploy"
                   }
             }
         spec{
              volume {
		      name = "wp-vol"
		      persistent_volume_claim { 
		      claim_name = kubernetes_persistent_volume_claim.pvc_wp.metadata.0.name
		      }
	      }
              container{
                   image="wordpress"
                   name="wp-app"
                   env {
                        name = "WORDPRESS_DB_HOST"
                        value = aws_db_instance.wp_rds.address
                   }
                   env {
                        name = "WORDPRESS_DB_NAME"
                        value = "wprds"
                   }
                   env {
                        name = "WORDPRESS_DB_USER"
                        value = "pratishtha"
                   }
                   env {
                        name = "WORDPRESS_DB_PASSWORD"
                        value = "pratishtha138"
                   }
                   volume_mount{
                        name       = "wp-vol"
                        mount_path ="/var/www/html"
                   }
                   port {
                        container_port = 80
                   }
               }
           }
       }
    }
}















resource "kubernetes_service" "wordpress"{
     metadata {
		name   = "wp-svc"
		labels = {
			env     = "Prod"
			Country = "Ind" 
		}
     }  
     depends_on = [kubernetes_deployment.wp-deploy]
     spec{
         type     = "NodePort"
	 selector = {
	 pod = "wp-deploy"
	 }
	 port {
		port = 80
	 }
     }
}



output "final_output" {
	value = kubernetes_service.wordpress.spec.0.port.0.node_port
}