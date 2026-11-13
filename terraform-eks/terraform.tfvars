aws_region                = "us-east-1"
cluster_name              = "kipper-eks"
backend_image             = "thiagofiec/manupred_be:latest" # substitua pela sua imagem exata do backend
frontend_image            = "thiagofiec/kipperfe:latest"
firebase_credentials_file = "serviceAccountKey.json"
db_username               = "kipperuser"
bash_path                 = "C:/Program Files/Git/bin/bash.exe" # caso use Linux/Mac, altere para "/bin/bash"

