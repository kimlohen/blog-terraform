# Blog Terraform

이 프로젝트는 **Terraform을 이용해 블로그 인프라를 구축하는 코드**입니다.

## 🚀 사용법

### 1️⃣ Terraform 설치  
[Terraform 설치 가이드](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)를 참고하세요.

---

### 2️⃣ 초기화  
```sh
terraform init
```

---

### 3️⃣ 실행 계획 확인
```sh
terraform plan
```

---

### 4️⃣ 인프라 적용
```sh
terraform apply
```

---

### 📁 폴더 구조
```
blog-terraform/
│── main.tf                 # 기본 Terraform 설정
│── variables.tf            # 변수 설정
│── .terraform.lock.hcl     # 프로바이더 버전 잠금 파일 (버전 일관성 유지)
│── .gitignore              # Git에서 제외할 파일 목록
└── README.md               # 프로젝트 설명 파일
```

---

### 📜 라이선스
이 프로젝트는 MIT License를 따릅니다.