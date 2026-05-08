resource "aws_iam_role" "this" {
  name                 = var.role_name
  path                 = var.role_path
  description          = var.description
  max_session_duration = var.max_session_duration
  assume_role_policy   = var.assume_role_policy
  tags                 = merge(var.tags, { ManagedBy = "terraform" })
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_policy" "inline" {
  count       = var.inline_policy_json != null ? 1 : 0
  name        = "${var.role_name}-inline-policy"
  description = "Inline policy for ${var.role_name}"
  policy      = var.inline_policy_json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "inline" {
  count      = var.inline_policy_json != null ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.inline[0].arn
}

# Cross-account trust policy extension — used during rehydration when roles
# must be assumed by a different account's EMR service.
resource "aws_iam_role_policy" "cross_account_trust" {
  count  = var.cross_account_policy_json != null ? 1 : 0
  name   = "${var.role_name}-cross-account"
  role   = aws_iam_role.this.id
  policy = var.cross_account_policy_json
}
