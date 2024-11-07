variable "names" {
  type = list(string)
  description = "List of unique names for the multiple resources."
  default = []
}

variable "passwords" {
  description = "A map of objects with password settings."
  type = map(
    object(
      {
        experation_days = optional(number, 0)
        length = number
        lower = optional(bool, false)
        min_lower = optional(number, 0)
        min_numeric = optional(number, 0)
        min_special = optional(number, 0)
        min_upper = optional(number, 0)
        numeric = optional(bool, true)
        override_special = optional(string, "!@#$%&*()-_=+[]{}<>:?")
        special = optional(bool, true)
        upper = optional(bool, true)
      }
    )
  )
}

variable "per_workspace" {
  type = bool
  description = "Generate a password for each workspace."
  default = false
}