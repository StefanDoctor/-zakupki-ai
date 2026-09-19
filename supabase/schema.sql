create extension if not exists pgcrypto;

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  telegram_id bigint not null unique,
  name text,
  created_at timestamptz not null default now()
);

create table if not exists clinics (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists clinic_members (
  clinic_id uuid not null references clinics(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  role text not null default 'member'
    check (role in ('owner', 'admin', 'member')),
  status text not null default 'active'
    check (status in ('active', 'invited', 'disabled')),
  created_at timestamptz not null default now(),
  primary key (clinic_id, user_id)
);

create table if not exists suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  status text not null default 'active'
    check (status in ('active', 'paused', 'blocked')),
  created_at timestamptz not null default now()
);

create table if not exists requests (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id),
  created_by uuid not null references users(id),
  status text not null default 'draft'
    check (
      status in (
        'draft',
        'ready',
        'sent',
        'offers_received',
        'selecting',
        'reserved',
        'ordered',
        'completed',
        'cancelled'
      )
    ),
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists request_positions (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references requests(id) on delete cascade,
  category text,
  product text,
  parameters jsonb not null default '{}'::jsonb,
  requirements jsonb not null default '[]'::jsonb,
  quantity numeric,
  quantity_unit text,
  status text not null default 'draft'
    check (
      status in (
        'draft',
        'ready',
        'sent',
        'offer_received',
        'selected',
        'cancelled',
        'fulfilled'
      )
    ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists offers (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references requests(id) on delete cascade,
  supplier_id uuid not null references suppliers(id),
  request_version integer not null,
  data jsonb not null default '{}'::jsonb,
  status text not null default 'active'
    check (
      status in (
        'active',
        'selected',
        'rejected',
        'expired',
        'stale',
        'needs_confirmation'
      )
    ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references requests(id),
  supplier_id uuid not null references suppliers(id),
  offer_id uuid not null references offers(id),
  status text not null default 'pending'
    check (
      status in (
        'pending',
        'reserve_requested',
        'reserved',
        'confirmed',
        'shipped',
        'received',
        'problem',
        'cancelled'
      )
    ),
  confirmed_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists audit_log (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid references clinics(id),
  user_id uuid references users(id),
  entity_type text not null,
  entity_id uuid,
  action text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_clinic_members_user
  on clinic_members(user_id);

create index if not exists idx_requests_clinic
  on requests(clinic_id);

create index if not exists idx_requests_created_by
  on requests(created_by);

create index if not exists idx_request_positions_request
  on request_positions(request_id);

create index if not exists idx_offers_request
  on offers(request_id);

create index if not exists idx_offers_supplier
  on offers(supplier_id);

create index if not exists idx_orders_request
  on orders(request_id);

create index if not exists idx_orders_supplier
  on orders(supplier_id);

create index if not exists idx_audit_log_clinic
  on audit_log(clinic_id);

create index if not exists idx_audit_log_entity
  on audit_log(entity_type, entity_id);

alter table users enable row level security;
alter table clinics enable row level security;
alter table clinic_members enable row level security;
alter table suppliers enable row level security;
alter table requests enable row level security;
alter table request_positions enable row level security;
alter table offers enable row level security;
alter table orders enable row level security;
alter table audit_log enable row level security;

comment on table users is
  'Application users linked to Telegram accounts.';

comment on table clinics is
  'Tenant organizations representing dental clinics.';

comment on table suppliers is
  'Suppliers participating in procurement.';

comment on table requests is
  'Procurement requests created by clinics.';

comment on table request_positions is
  'Normalized individual positions inside a procurement request.';

comment on table offers is
  'Supplier offers for a specific request version.';

comment on table orders is
  'Orders created after explicit clinic selection/confirmation.';

comment on table audit_log is
  'Immutable-style application audit trail.';

-- The MVP backend will use the Supabase service-role key only on the server.
-- The service-role key must never be exposed to the browser.
