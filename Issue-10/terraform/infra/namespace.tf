resource "kubernetes_namespace" "vantra_billing" {
  metadata {
    name = var.k8s_namespace
  }

  depends_on = [module.eks]
}
