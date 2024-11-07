variable "context_name" {
  description = "The CircleCI context to add variables to."
  type = string
  default = null
}

variable "env" {
  description = "Project environmental variables."
  type = any
}

variable "schedules" {
  description = "Set a scheduled pipeline."
  type = any
  default = {}  
}

variable "secrets" {
  description = "Sensitive credentials to be used with the application."
  type = map(string)
  default = {}
}
