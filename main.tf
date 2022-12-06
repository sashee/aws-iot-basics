resource "random_id" "id" {
  byte_length = 8
}

resource "tls_private_key" "key" {
  algorithm   = "RSA"
	rsa_bits = 2048
}

resource "tls_self_signed_cert" "cert" {
  private_key_pem = tls_private_key.key.private_key_pem

  validity_period_hours = 240

  allowed_uses = [
  ]

	subject {
		organization = "test"
	}
}

resource "aws_iot_certificate" "cert" {
	certificate_pem = trimspace(tls_self_signed_cert.cert.cert_pem)
	active          = true
}

data "aws_arn" "thing" {
  arn = aws_iot_thing.thing.arn
}

resource "aws_iot_policy" "policy" {
  name = "thingpolicy_${random_id.id.hex}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iot:Connect",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:iot:${data.aws_arn.thing.region}:${data.aws_arn.thing.account}:client/$${iot:Connection.Thing.ThingName}"
      },
      {
        Action = [
          "iot:Publish",
          "iot:Receive",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:iot:${data.aws_arn.thing.region}:${data.aws_arn.thing.account}:topic/$aws/things/$${iot:Connection.Thing.ThingName}/*"
      },
      {
        Action = [
          "iot:Subscribe",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:iot:${data.aws_arn.thing.region}:${data.aws_arn.thing.account}:topicfilter/$aws/things/$${iot:Connection.Thing.ThingName}/*"
      },
    ]
  })
}

resource "aws_iot_policy_attachment" "attachment" {
  policy = aws_iot_policy.policy.name
  target = aws_iot_certificate.cert.arn
}

resource "aws_iot_thing" "thing" {
  name = "thing_${random_id.id.hex}"
}

resource "aws_iot_thing_principal_attachment" "attachment" {
  principal = aws_iot_certificate.cert.arn
  thing     = aws_iot_thing.thing.name
}

data "http" "root_ca" {
  url = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
}

data "aws_iot_endpoint" "iot_endpoint" {
	endpoint_type = "iot:Data-ATS"
}

output "ca" {
	value = data.http.root_ca.response_body
}

output "iot_endpoint" {
	value = data.aws_iot_endpoint.iot_endpoint.endpoint_address
}

output "thing_name" {
	value = aws_iot_thing.thing.name
}

output "cert" {
	value = tls_self_signed_cert.cert.cert_pem
}

output "key" {
	value = tls_private_key.key.private_key_pem
	sensitive = true
}
