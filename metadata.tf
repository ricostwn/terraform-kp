resource "google_compute_project_metadata" "my_ssh_key" {
  metadata = {
    ssh-keys = <<EOF
      53buahapel:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINcKh/iqrJbKjs5/1TTRIKbocg/9f9begTBSvb6TapDc apel@unknown
      nathanaelrico:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDEKGOHx+RA3NJnfnTQmlILAic0E8Ys8oRqA2keilkmD nathanaelrico10@gmail.com
    EOF
  }
}
