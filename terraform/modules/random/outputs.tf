output "results" {
  description = "A map(string) with the following attributes: result, md5, sha1sha256, and sha512."
  value = merge(
    merge(
      flatten([
        for key, value in var.passwords : {
          "${key}"  = {
            md5     = md5(random_password.single[key].result)
            result  = random_password.single[key].result
            sha1    = sha1(random_password.single[key].result)
            sha256  = sha256(random_password.single[key].result)
            sha512  = sha512(random_password.single[key].result)            
          }
        } if !var.per_workspace
      ])
    ...),
    merge(
      flatten([
        for key, value in local.passwords : {
          "${key}"  = {
            md5     = md5(random_password.multiple[key].result)
            result  = random_password.multiple[key].result
            sha1    = sha1(random_password.multiple[key].result)
            sha256  = sha256(random_password.multiple[key].result)
            sha512  = sha512(random_password.multiple[key].result)            
          }
        } if var.per_workspace
      ])
  ...)
  )
}