variable "project_name" {
  description = "プロジェクト名"

  type = string
}


variable "container_image_tag" {
  description = "ECRイメージタグ"

  type = string

  default = "latest"
}
