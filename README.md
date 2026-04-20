# terraform-port

AWS上に本番環境を構築するTerraformプロジェクトです。  
ECS Fargate + Aurora MySQL + ALB によるコンテナAPIの運用基盤を提供します。

---

## ディレクトリ構成

```
terraform-port/
├── backend/               # S3 バックエンド（tfstate管理用）のリソース定義
│   └── main.tf
├── environments/
│   └── prod/              # 本番環境のエントリーポイント
│       ├── main.tf        # モジュール呼び出し・プロバイダー設定
│       ├── variables.tf   # 環境変数定義
│       ├── backend.tf     # S3リモートステート設定
│       └── ecr/           # ECRのみ分離した別ステート
│           ├── main.tf
│           └── backend.tf
└── modules/
    ├── base/              # ネットワーク・DB基盤
    │   ├── main.tf
    │   ├── variables.tf
    │   └── output.tf
    ├── api/               # ECS Fargate + ALB
    │   ├── main.tf
    │   └── variables.tf
    └── ecr/               # ECRリポジトリ
        ├── main.tf
        ├── variables.tf
        └── output.tf
```

---

## モジュール説明

### `modules/base` — 基盤インフラ

VPC・サブネット・NAT・RDS・セキュリティグループを構築します。

| リソース | 内容 |
|---|---|
| VPC | CIDR `10.0.0.0/21`、2 AZ（ap-northeast-1a/c）|
| サブネット | Public（ALB用）/ Protected（ECS+NAT用）/ Private（RDS用）の3層 |
| RDS | Aurora MySQL 8.0、t3.medium、暗号化・自動バックアップ有効 |
| セキュリティグループ | ALB→API(8000)→DB(3306) の最小権限チェーン |
| S3 | ALBアクセスログ保存用バケット＋VPCエンドポイント |

### `modules/api` — APIアプリケーション層

ECS Fargate で API コンテナを稼働させます。

| リソース | 内容 |
|---|---|
| ALB | 本番リスナー:80 / テストリスナー:8080 |
| ECS Cluster/Service | Fargate、ARM64、256CPU/512MB |
| Blue/Green デプロイ | ゼロダウンタイム、ベイク時間1分、自動ロールバック |
| Auto Scaling | CPU 70%でスケールアウト、Min:1 / Max:2 |
| IAM | タスク実行ロール（ECR・SSM・CloudWatch）/ ECS Exec 用ロール |

DBパスワードは SSM Parameter Store（`/devops/prod/db/password`）から取得します。

### `modules/ecr` — コンテナレジストリ

ECRリポジトリ（`devops-prod-api`）を作成します。最新5世代のイメージを保持し、古いイメージを自動削除するライフサイクルポリシーが設定されています。

---

## terraform apply 実行手順

### 前提条件

- AWS CLI 設定済み（`aws configure`）
- SSM Parameter Store に DB パスワード登録済み

```bash
aws ssm put-parameter \
  --name "/devops/prod/db/password" \
  --value "<パスワード>" \
  --type "SecureString"
```

### Step 1: S3 バックエンドの構築（初回のみ）

```bash
cd backend
terraform init
terraform apply
```

### Step 2: ECR リポジトリの作成

```bash
cd environments/prod/ecr
terraform init
terraform apply
```

### Step 3: Docker イメージのビルド & プッシュ

```bash
# ECR へログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin <account_id>.dkr.ecr.ap-northeast-1.amazonaws.com

# ビルド & プッシュ
docker build -t devops-prod-api .
docker tag devops-prod-api:latest <account_id>.dkr.ecr.ap-northeast-1.amazonaws.com/devops-prod-api:latest
docker push <account_id>.dkr.ecr.ap-northeast-1.amazonaws.com/devops-prod-api:latest
```

### Step 4: 本番環境の構築

```bash
cd environments/prod
terraform init
terraform apply
```

---

## 環境削除手順（terraform destroy）

> **注意**: 削除は逆順で行います。依存関係があるため順番が重要です。

### Step 1: 本番環境（ECS・ALB・VPC・RDS）を削除

```bash
cd environments/prod
terraform destroy
```

### Step 2: ECR リポジトリを削除

```bash
cd environments/prod/ecr
terraform destroy
```

> `force_delete = true` が設定されているため、イメージが残っていても削除されます。

### Step 3: S3 バックエンドを削除（完全撤去する場合のみ）

```bash
cd backend
terraform destroy
```

> tfstate が S3 に残っている場合は、先に手動で S3 バケットを空にする必要があります。

---

## 構成情報

| 項目 | 値 |
|---|---|
| AWSリージョン | ap-northeast-1（東京）|
| Terraform バージョン | >= 1.0.0 |
| AWS プロバイダー | ~> 6.0 |
| リモートステート | `s3://devops-test-tfstate-20260409/prod/terraform.tfstate` |
