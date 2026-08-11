pipeline {
    agent any

    environment {
        AWS_REGION   = 'ap-south-1'
        ECR_REPO     = 'vantra/billing-invoice-service'
        IMAGE_TAG    = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                sh 'docker build -t ${ECR_REPO}:${IMAGE_TAG} .'
            }
        }

        stage('Login & Push to ECR') {
            steps {
                sh '''
                    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                    ECR_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                    aws ecr get-login-password --region ${AWS_REGION} \
                      | docker login --username AWS --password-stdin ${ECR_URL}

                    docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URL}/${ECR_REPO}:${IMAGE_TAG}
                    docker push ${ECR_URL}/${ECR_REPO}:${IMAGE_TAG}

                    echo "${ECR_URL}/${ECR_REPO}:${IMAGE_TAG}" > image_uri.txt
                '''
            }
        }

        stage('Deploy') {
            steps {
                dir('scripts') {
                    sh 'chmod +x deploy_via_ssm.sh && ./deploy_via_ssm.sh "$(cat ../image_uri.txt)"'
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully. billing-invoice-service deployed.'
        }
        failure {
            echo 'Pipeline failed - check stage logs above.'
        }
    }
}
