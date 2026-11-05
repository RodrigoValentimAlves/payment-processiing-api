CREATE TABLE customers (
    id UUID PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(320) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT chk_customers_status CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

CREATE UNIQUE INDEX uk_customers_email_lower ON customers (LOWER(email));

CREATE TABLE payment_methods (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL,
    type VARCHAR(30) NOT NULL,
    provider_reference VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT fk_payment_methods_customer
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE RESTRICT,
    CONSTRAINT uk_payment_methods_id_customer UNIQUE (id, customer_id),
    CONSTRAINT uk_payment_methods_provider_reference UNIQUE (provider_reference),
    CONSTRAINT chk_payment_methods_type CHECK (type IN ('CARD', 'PIX', 'BANK_TRANSFER')),
    CONSTRAINT chk_payment_methods_status CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

CREATE INDEX idx_payment_methods_customer_id ON payment_methods (customer_id);

CREATE TABLE payments (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL,
    payment_method_id UUID NOT NULL,
    amount NUMERIC(19, 2) NOT NULL,
    currency CHAR(3) NOT NULL,
    status VARCHAR(30) NOT NULL,
    provider_reference VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT fk_payments_payment_method
        FOREIGN KEY (payment_method_id, customer_id)
        REFERENCES payment_methods (id, customer_id) ON DELETE RESTRICT,
    CONSTRAINT uk_payments_id_customer UNIQUE (id, customer_id),
    CONSTRAINT uk_payments_provider_reference UNIQUE (provider_reference),
    CONSTRAINT chk_payments_amount_positive CHECK (amount > 0),
    CONSTRAINT chk_payments_currency_uppercase CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_payments_status
        CHECK (status IN ('PENDING', 'APPROVED', 'DECLINED', 'PARTIALLY_REFUNDED', 'REFUNDED'))
);

CREATE INDEX idx_payments_customer_created_at ON payments (customer_id, created_at DESC);
CREATE INDEX idx_payments_payment_method_id ON payments (payment_method_id);

CREATE TABLE refunds (
    id UUID PRIMARY KEY,
    payment_id UUID NOT NULL,
    amount NUMERIC(19, 2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    reason VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT fk_refunds_payment
        FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE RESTRICT,
    CONSTRAINT chk_refunds_amount_positive CHECK (amount > 0),
    CONSTRAINT chk_refunds_status CHECK (status IN ('REQUESTED', 'APPROVED', 'REJECTED'))
);

CREATE INDEX idx_refunds_payment_id ON refunds (payment_id);

CREATE TABLE payment_events (
    id UUID PRIMARY KEY,
    payment_id UUID NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    previous_status VARCHAR(30),
    new_status VARCHAR(30),
    details JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT fk_payment_events_payment
        FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE RESTRICT
);

CREATE INDEX idx_payment_events_payment_occurred_at
    ON payment_events (payment_id, occurred_at);

CREATE TABLE idempotency_keys (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL,
    payment_id UUID,
    idempotency_key VARCHAR(255) NOT NULL,
    request_hash CHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ,
    CONSTRAINT fk_idempotency_keys_customer
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE RESTRICT,
    CONSTRAINT fk_idempotency_keys_payment
        FOREIGN KEY (payment_id, customer_id)
        REFERENCES payments (id, customer_id) ON DELETE RESTRICT,
    CONSTRAINT uk_idempotency_keys_customer_key UNIQUE (customer_id, idempotency_key),
    CONSTRAINT uk_idempotency_keys_payment UNIQUE (payment_id)
);

CREATE INDEX idx_idempotency_keys_expires_at ON idempotency_keys (expires_at);
