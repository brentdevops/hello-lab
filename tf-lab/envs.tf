module "app_dev" {
  source = "./modules/bucket"
  name   = "app"
  env    = "dev"
}

module "app_prod" {
  source = "./modules/bucket"
  name   = "app"
  env    = "prod"
}

output "dev_bucket" {
  value = module.app_dev.bucket_name
}

output "prod_bucket" {
  value = module.app_prod.bucket_name
}

module "app_staging" {
  source = "./modules/bucket"
  name   = "app"
  env    = "staging"
}
