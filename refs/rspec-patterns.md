# RSpec patterns reference

Lazy-loaded by `rails-tests` only when a task needs depth beyond the agent's non-negotiables.

## Spec types and when to use each

| Type | Use for |
|---|---|
| Model spec | Validations, associations, scopes, instance methods, business logic |
| Request spec | Controller behavior, status codes, response body, side effects, authorization |
| System spec | End-to-end browser flow (slow, use sparingly) |
| Job spec | ActiveJob queueing and execution |
| Mailer spec | Mail delivery and content |
| View spec | RARELY useful — prefer request specs that assert rendered output |

Avoid controller specs (the `type: :controller` style). They're deprecated in spirit and don't test real behavior.

## Model specs

```ruby
RSpec.describe User, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }

    context "when email domain is blacklisted" do
      it "rejects the email" do
        user = build(:user, email: "test@spam.com")
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("domain is not allowed")
      end
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:posts).dependent(:destroy) }
    it { is_expected.to belong_to(:organization).optional }
  end

  describe "scopes" do
    describe ".active" do
      it "returns only users with active status" do
        active = create(:user, status: :active)
        create(:user, status: :inactive)

        expect(User.active).to eq([active])
      end
    end
  end

  describe "#full_name" do
    it "combines first and last name" do
      user = build(:user, first_name: "Jane", last_name: "Doe")
      expect(user.full_name).to eq("Jane Doe")
    end
  end
end
```

Group by category, not by method name. Use `build` or `build_stubbed` unless you need DB queries — only `create` when the test depends on persisted state.

## Request specs

Primary controller-level test. Test status codes, response body, side effects, authorization.

```ruby
RSpec.describe "Users API", type: :request do
  describe "GET /api/v1/users" do
    it "returns paginated users" do
      create_list(:user, 3)

      get "/api/v1/users", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].size).to eq(3)
      expect(json_response).to have_key("meta")
    end

    it "returns 401 without auth" do
      get "/api/v1/users"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /users" do
    it "creates a user with valid params" do
      expect {
        post "/users", params: { user: valid_attributes }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(User.last)
      follow_redirect!
      expect(response.body).to include("Welcome")
    end

    it "returns 422 with invalid params" do
      post "/users", params: { user: { email: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Email can't be blank")
    end
  end
end
```

## Factories

Keep factories minimal — override per-test, not in the factory definition.

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }

    trait :admin do
      admin { true }
    end
  end
end

# In specs
let(:admin) { create(:user, :admin) }
let(:guest) { build_stubbed(:user) }   # no DB hit
```

Factory traits over factory subclasses. Sequences for unique fields. No `create` in factory definitions (creates cascading writes).

## TDD discipline

### Red phase

1. Read the orchestrator's plan
2. Write the spec for the behavior that doesn't exist yet
3. Run it — confirm it fails for the RIGHT reason:
   - `NoMethodError` (method doesn't exist) ✓
   - `ActionController::RoutingError` (route missing) ✓
   - Wrong return value ✓
   - `NameError`, syntax error ✗ — fix the spec
4. Return to orchestrator with the failing test command and expected reason

### Green phase

1. Run the suite
2. If something regressed, report — don't modify the failing spec to pass
3. If new behavior lacks coverage (implementation specialist handled an edge case but didn't test it), add the missing test

## Common matchers

```ruby
# HTTP status
expect(response).to have_http_status(:ok)         # 200
expect(response).to have_http_status(:created)    # 201
expect(response).to have_http_status(:unprocessable_entity)  # 422
expect(response).to have_http_status(:see_other)  # 303

# Side effects
expect { do_thing }.to change(Model, :count).by(1)
expect { do_thing }.to change { user.reload.role }.from("guest").to("admin")
expect { do_thing }.not_to change(Model, :count)

# Job enqueuing (with ActiveJob test adapter)
expect { trigger_action }.to have_enqueued_job(NotifyJob).with(user)
expect(NotifyJob).to have_been_enqueued.exactly(:once)

# Mail
expect { trigger_action }.to change { ActionMailer::Base.deliveries.count }.by(1)
expect(ActionMailer::Base.deliveries.last.to).to eq(["user@example.com"])

# Time
freeze_time { ... }   # ActiveSupport::Testing::TimeHelpers
travel_to(2.days.from_now) { ... }
```

## Performance hygiene

- `build_stubbed` over `build` over `create` (in that order of preference)
- `let` over `before` for DB-touching setup (lazy)
- Tag slow specs: `it "...", :slow do` then `--tag ~slow` for fast loops
- Don't `create_list(:user, 100)` when 3 will do
- No real HTTP. Use VCR or stub with `allow_any_instance_of(...)` (sparingly).

## Spec smells

| Smell | Fix |
|---|---|
| Test passes whether or not the code works | Delete it — it can't fail meaningfully |
| `.first`, `.last`, `.find_by` in assertions | Sort explicitly; rely on stable IDs |
| Multiple `before` blocks setting up the same data | Move to a shared `let` |
| Big shared `before(:all)` | Use `let` or per-example `before(:each)` |
| `expect(user).to be_valid` followed by no other assertion | Test what the validation actually validates |
