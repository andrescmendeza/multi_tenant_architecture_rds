# Encryption key for build artifacts
resource "aws_kms_key" "db" {
  description             = "db-encryption-key"
  deletion_window_in_days = 10
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN SUBNET GROUP ACROSS ALL THE SUBNETS OF THE DEFAULT ASG TO HOST THE RDS INSTANCE
# ---------------------------------------------------------------------------------------------------------------------


resource "aws_db_subnet_group" "db" {
  name       = "${terraform.workspace}-db-subnet-group"
  subnet_ids = aws_subnet.private.*.id

  tags = {
    Name = "${terraform.workspace}-db-subnet-group"
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP TO ALLOW ACCESS TO THE RDS INSTANCE
# ---------------------------------------------------------------------------------------------------------------------


resource "aws_security_group" "db" {
  name        = "${terraform.workspace}-db"
  description = "allow inbound access from ecs-tasks"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    protocol  = "tcp"
    from_port = 3306
    to_port   = 3306
    security_groups = [
      aws_security_group.lb-sg.id,
    ]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE DATABASE INSTANCE
# ---------------------------------------------------------------------------------------------------------------------


resource "aws_db_instance" "db" {

  identifier           = "${terraform.workspace}-tms-db"
  engine               = "mysql"
  engine_version       = "8.0.23"
  port                 = "3306"
  db_name              = "tms"
  username             = var.db_username
  password             = var.db_password
  instance_class       = "db.t3.medium"
  allocated_storage    = 5
  skip_final_snapshot  = true
  license_model        = var.db_license_model
  db_subnet_group_name = aws_db_subnet_group.db.name
  vpc_security_group_ids = [
    aws_vpc.vpc.default_security_group_id,
    aws_security_group.db.id
  ]
  deletion_protection     = false
  backup_retention_period = 7
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.db.arn

  tags = {
    Name        = "${terraform.workspace} tms database "
    environment = terraform.workspace
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE S3 Bucket and IAM Role
# ---------------------------------------------------------------------------------------------------------------------


# Encryption key for build artifacts
resource "aws_kms_key" "db_backup" {
  description             = "db-backup-encryption-key"
  deletion_window_in_days = 10
}

resource "aws_iam_role" "db_backup" {
  name = "db-backup-role"
  path = "/"

  assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Action":"sts:AssumeRole",
              "Principal": {
                 "Service":"s3.amazonaws.com",
                 "Service":"kms.amazonaws.com",
                 "Service":"export.rds.amazonaws.com",
                 "Service": "rds.amazonaws.com"
              },
              "Effect": "Allow",
              "Sid": "DbBackupRolePolicy"
          }
      ]
}
EOF
}

resource "aws_iam_role_policy" "db_backup" {
  name = "db-backup-default-policy"
  role = aws_iam_role.db_backup.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "*",
            "Effect": "Allow",
            "Condition": {
                "StringEqualsIfExists": {
                    "iam:PassedToService": [
                        "kms.amazonaws.com",
                        "rds.amazonaws.com"
                    ]
                }
            }
        },{
          "Effect":"Allow",
          "Action": [
            "s3:*"
          ],
          "Resource": [
            "${aws_s3_bucket.db_backup.arn}",
            "${aws_s3_bucket.db_backup.arn}/*"
          ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:*"
            ],
            "Resource": "${aws_kms_key.db_backup.arn}"
        }
    ]
}
EOF
}

data "aws_iam_policy_document" "db_backup" {

  policy_id = "PolicyForDbBackupRole"

  statement {

    sid = 1

    actions = [
      "s3:PutObject*",
      "s3:GetObject*",
      "s3:DeleteObject*"
    ]

    resources = [
      "arn:aws:s3:::db-backup.tms/*"
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.db_backup.arn]
    }
  }

  statement {

    sid = 2

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      "arn:aws:s3:::db-backup.tms"
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.db_backup.arn]
    }
  }
}

resource "aws_s3_bucket" "db_backup" {
  bucket = "db-backup.tms"
  tags = {
    Name = "db-backup-tms"
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
  bucket = aws_s3_bucket.db_backup.id
  policy = data.aws_iam_policy_document.db_backup.json
}

resource "aws_s3_bucket_acl" "db_backup_bucket_acl" {
  bucket = aws_s3_bucket.db_backup.id
  acl    = "private"
}

output "db_backup_kms_key_arn" {
  value = aws_kms_key.db_backup.arn
}

output "db_backup_kms_key_id" {
  value = aws_kms_key.db_backup.id
}

output "db_backup_s3_bucket" {
  value = aws_s3_bucket.db_backup.bucket
}

output "db_backup_role" {
  value = aws_iam_role.db_backup.arn
}


