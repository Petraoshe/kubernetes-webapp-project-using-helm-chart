variable "ami" {
  default = "ami-0d09654d0a20d3ae2"
}
variable "instance-type" {
  default = "t3.medium"
}
variable "kubenetes-key" {
  default     = "~/Keypairs/kubenetes-key.pub"
  description = "path to my keypairs"
}
variable "keyname" {
  default = "kubenetes-key"
}

variable "cluster_init_yml" {
  default     = "~/Downloads/kubernetes_project copy/yml/cluster.yml"
  description = "this is path to the join.yml file"
}