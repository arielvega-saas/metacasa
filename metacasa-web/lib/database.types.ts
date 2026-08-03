export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.1"
  }
  public: {
    Tables: {
      accounts: {
        Row: {
          account_number_last4: string | null
          color: string | null
          created_at: string
          created_by: string | null
          currency: string
          display_order: number
          household_id: string
          icon: string | null
          id: string
          institution: string | null
          is_active: boolean
          name: string
          notes: string | null
          owner_user_id: string | null
          ownership: string | null
          starting_balance: number
          type: string
          updated_at: string
        }
        Insert: {
          account_number_last4?: string | null
          color?: string | null
          created_at?: string
          created_by?: string | null
          currency?: string
          display_order?: number
          household_id?: string
          icon?: string | null
          id?: string
          institution?: string | null
          is_active?: boolean
          name: string
          notes?: string | null
          owner_user_id?: string | null
          ownership?: string | null
          starting_balance?: number
          type: string
          updated_at?: string
        }
        Update: {
          account_number_last4?: string | null
          color?: string | null
          created_at?: string
          created_by?: string | null
          currency?: string
          display_order?: number
          household_id?: string
          icon?: string | null
          id?: string
          institution?: string | null
          is_active?: boolean
          name?: string
          notes?: string | null
          owner_user_id?: string | null
          ownership?: string | null
          starting_balance?: number
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "accounts_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_usage_daily: {
        Row: {
          cache_read_tokens: number
          cache_write_tokens: number
          day: string
          input_tokens: number
          last_request_at: string
          output_tokens: number
          request_count: number
          user_id: string
        }
        Insert: {
          cache_read_tokens?: number
          cache_write_tokens?: number
          day?: string
          input_tokens?: number
          last_request_at?: string
          output_tokens?: number
          request_count?: number
          user_id: string
        }
        Update: {
          cache_read_tokens?: number
          cache_write_tokens?: number
          day?: string
          input_tokens?: number
          last_request_at?: string
          output_tokens?: number
          request_count?: number
          user_id?: string
        }
        Relationships: []
      }
      bills: {
        Row: {
          account_id: string | null
          amount: number
          amount_original: number | null
          category: string
          created_at: string
          created_by: string | null
          currency: string
          currency_original: string | null
          description: string | null
          due_date: string
          fx_rate_to_base: number | null
          household_id: string
          id: string
          note: string | null
          paid_at: string | null
          recurrence_type: string | null
          recurring: boolean
          reminder_days: number | null
          status: string
          title: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          account_id?: string | null
          amount?: number
          amount_original?: number | null
          category?: string
          created_at?: string
          created_by?: string | null
          currency?: string
          currency_original?: string | null
          description?: string | null
          due_date: string
          fx_rate_to_base?: number | null
          household_id?: string
          id?: string
          note?: string | null
          paid_at?: string | null
          recurrence_type?: string | null
          recurring?: boolean
          reminder_days?: number | null
          status?: string
          title: string
          updated_at?: string | null
          user_id?: string
        }
        Update: {
          account_id?: string | null
          amount?: number
          amount_original?: number | null
          category?: string
          created_at?: string
          created_by?: string | null
          currency?: string
          currency_original?: string | null
          description?: string | null
          due_date?: string
          fx_rate_to_base?: number | null
          household_id?: string
          id?: string
          note?: string | null
          paid_at?: string | null
          recurrence_type?: string | null
          recurring?: boolean
          reminder_days?: number | null
          status?: string
          title?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bills_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bills_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      budget_allocations: {
        Row: {
          allocated: number
          category: string
          created_at: string
          currency: string
          id: string
          period_id: string
          rollover_from_prev: number
          rollover_mode: string
          subcategory: string
          updated_at: string
        }
        Insert: {
          allocated?: number
          category: string
          created_at?: string
          currency?: string
          id?: string
          period_id: string
          rollover_from_prev?: number
          rollover_mode?: string
          subcategory?: string
          updated_at?: string
        }
        Update: {
          allocated?: number
          category?: string
          created_at?: string
          currency?: string
          id?: string
          period_id?: string
          rollover_from_prev?: number
          rollover_mode?: string
          subcategory?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "budget_allocations_period_id_fkey"
            columns: ["period_id"]
            isOneToOne: false
            referencedRelation: "budget_periods"
            referencedColumns: ["id"]
          },
        ]
      }
      budget_periods: {
        Row: {
          created_at: string
          household_id: string
          id: string
          notes: string | null
          period_end: string
          period_start: string
          period_type: string
          ready_to_assign: number
          total_allocated: number
          total_income: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          household_id?: string
          id?: string
          notes?: string | null
          period_end: string
          period_start: string
          period_type?: string
          ready_to_assign?: number
          total_allocated?: number
          total_income?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          household_id?: string
          id?: string
          notes?: string | null
          period_end?: string
          period_start?: string
          period_type?: string
          ready_to_assign?: number
          total_allocated?: number
          total_income?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "budget_periods_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      budgets: {
        Row: {
          account: string
          amount: number
          amount_original: number | null
          category: string
          currency: string
          currency_original: string | null
          fx_rate_to_base: number | null
          household_id: string
          id: string
          subcategory: string
          updated_at: string
          user_id: string
        }
        Insert: {
          account?: string
          amount?: number
          amount_original?: number | null
          category: string
          currency?: string
          currency_original?: string | null
          fx_rate_to_base?: number | null
          household_id?: string
          id?: string
          subcategory?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          account?: string
          amount?: number
          amount_original?: number | null
          category?: string
          currency?: string
          currency_original?: string | null
          fx_rate_to_base?: number | null
          household_id?: string
          id?: string
          subcategory?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "budgets_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      categories: {
        Row: {
          data: Json
          household_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          data?: Json
          household_id?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          data?: Json
          household_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "categories_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: true
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      category_rules: {
        Row: {
          category: string
          hits: number
          household_id: string
          id: string
          pattern: string
          source: string
          subcategory: string | null
          updated_at: string
        }
        Insert: {
          category: string
          hits?: number
          household_id: string
          id?: string
          pattern: string
          source?: string
          subcategory?: string | null
          updated_at?: string
        }
        Update: {
          category?: string
          hits?: number
          household_id?: string
          id?: string
          pattern?: string
          source?: string
          subcategory?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "category_rules_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      connected_wallets: {
        Row: {
          access_token: string | null
          access_token_encrypted: string | null
          balance: number | null
          created_at: string | null
          currency: string | null
          household_id: string
          id: string
          is_active: boolean | null
          last_sync: string | null
          metadata: Json | null
          name: string
          provider: string
          user_id: string
        }
        Insert: {
          access_token?: string | null
          access_token_encrypted?: string | null
          balance?: number | null
          created_at?: string | null
          currency?: string | null
          household_id?: string
          id?: string
          is_active?: boolean | null
          last_sync?: string | null
          metadata?: Json | null
          name: string
          provider: string
          user_id: string
        }
        Update: {
          access_token?: string | null
          access_token_encrypted?: string | null
          balance?: number | null
          created_at?: string | null
          currency?: string | null
          household_id?: string
          id?: string
          is_active?: boolean | null
          last_sync?: string | null
          metadata?: Json | null
          name?: string
          provider?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "connected_wallets_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      credit_cards: {
        Row: {
          account_id: string
          created_at: string
          credit_limit: number
          due_day: number
          interest_rate_monthly: number
          last_statement_amount: number | null
          last_statement_date: string | null
          minimum_payment_pct: number
          network: string | null
          statement_day: number
          updated_at: string
        }
        Insert: {
          account_id: string
          created_at?: string
          credit_limit: number
          due_day: number
          interest_rate_monthly?: number
          last_statement_amount?: number | null
          last_statement_date?: string | null
          minimum_payment_pct?: number
          network?: string | null
          statement_day: number
          updated_at?: string
        }
        Update: {
          account_id?: string
          created_at?: string
          credit_limit?: number
          due_day?: number
          interest_rate_monthly?: number
          last_statement_amount?: number | null
          last_statement_date?: string | null
          minimum_payment_pct?: number
          network?: string | null
          statement_day?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "credit_cards_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: true
            referencedRelation: "accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      debts: {
        Row: {
          annual_rate: number
          category: string | null
          created_at: string | null
          created_by: string | null
          creditor: string
          currency: string
          current_balance: number
          household_id: string
          id: string
          maturity_date: string | null
          monthly_payment: number | null
          note: string | null
          original_amount: number
          start_date: string
          status: string | null
          updated_at: string | null
        }
        Insert: {
          annual_rate?: number
          category?: string | null
          created_at?: string | null
          created_by?: string | null
          creditor: string
          currency?: string
          current_balance: number
          household_id: string
          id?: string
          maturity_date?: string | null
          monthly_payment?: number | null
          note?: string | null
          original_amount: number
          start_date: string
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          annual_rate?: number
          category?: string | null
          created_at?: string | null
          created_by?: string | null
          creditor?: string
          currency?: string
          current_balance?: number
          household_id?: string
          id?: string
          maturity_date?: string | null
          monthly_payment?: number | null
          note?: string | null
          original_amount?: number
          start_date?: string
          status?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "debts_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      email_waitlist: {
        Row: {
          created_at: string
          email: string
          id: string
          lang: string | null
          source: string | null
          user_agent: string | null
        }
        Insert: {
          created_at?: string
          email: string
          id?: string
          lang?: string | null
          source?: string | null
          user_agent?: string | null
        }
        Update: {
          created_at?: string
          email?: string
          id?: string
          lang?: string | null
          source?: string | null
          user_agent?: string | null
        }
        Relationships: []
      }
      fx_rates: {
        Row: {
          base_currency: string
          created_at: string
          quote_currency: string
          rate: number
          rate_date: string
          source: string
        }
        Insert: {
          base_currency: string
          created_at?: string
          quote_currency: string
          rate: number
          rate_date: string
          source?: string
        }
        Update: {
          base_currency?: string
          created_at?: string
          quote_currency?: string
          rate?: number
          rate_date?: string
          source?: string
        }
        Relationships: []
      }
      goal_contributions: {
        Row: {
          amount: number
          contributed_at: string
          contributed_by: string | null
          goal_id: string
          id: string
          notes: string | null
          transaction_id: string | null
        }
        Insert: {
          amount: number
          contributed_at?: string
          contributed_by?: string | null
          goal_id: string
          id?: string
          notes?: string | null
          transaction_id?: string | null
        }
        Update: {
          amount?: number
          contributed_at?: string
          contributed_by?: string | null
          goal_id?: string
          id?: string
          notes?: string | null
          transaction_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "goal_contributions_goal_id_fkey"
            columns: ["goal_id"]
            isOneToOne: false
            referencedRelation: "goals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "goal_contributions_transaction_id_fkey"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      goals: {
        Row: {
          account_id: string | null
          category: string | null
          color: string | null
          completed_at: string | null
          created_at: string
          created_by: string | null
          currency: string
          current_amount: number
          description: string | null
          household_id: string
          icon: string | null
          id: string
          name: string
          notes: string | null
          priority: number
          status: string
          target_amount: number
          target_date: string | null
          updated_at: string
        }
        Insert: {
          account_id?: string | null
          category?: string | null
          color?: string | null
          completed_at?: string | null
          created_at?: string
          created_by?: string | null
          currency?: string
          current_amount?: number
          description?: string | null
          household_id?: string
          icon?: string | null
          id?: string
          name: string
          notes?: string | null
          priority?: number
          status?: string
          target_amount: number
          target_date?: string | null
          updated_at?: string
        }
        Update: {
          account_id?: string | null
          category?: string | null
          color?: string | null
          completed_at?: string | null
          created_at?: string
          created_by?: string | null
          currency?: string
          current_amount?: number
          description?: string | null
          household_id?: string
          icon?: string | null
          id?: string
          name?: string
          notes?: string | null
          priority?: number
          status?: string
          target_amount?: number
          target_date?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "goals_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "goals_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      household_invitations: {
        Row: {
          accepted_at: string | null
          accepted_by: string | null
          created_at: string
          email: string
          expires_at: string
          household_id: string
          id: string
          invite_token: string
          invited_by: string
          role: string
          status: string
        }
        Insert: {
          accepted_at?: string | null
          accepted_by?: string | null
          created_at?: string
          email: string
          expires_at?: string
          household_id: string
          id?: string
          invite_token?: string
          invited_by: string
          role?: string
          status?: string
        }
        Update: {
          accepted_at?: string | null
          accepted_by?: string | null
          created_at?: string
          email?: string
          expires_at?: string
          household_id?: string
          id?: string
          invite_token?: string
          invited_by?: string
          role?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "household_invitations_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      household_members: {
        Row: {
          display_name: string | null
          household_id: string
          invited_by: string | null
          joined_at: string
          role: string
          user_id: string
        }
        Insert: {
          display_name?: string | null
          household_id: string
          invited_by?: string | null
          joined_at?: string
          role?: string
          user_id: string
        }
        Update: {
          display_name?: string | null
          household_id?: string
          invited_by?: string | null
          joined_at?: string
          role?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "household_members_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      households: {
        Row: {
          created_at: string
          created_by: string | null
          default_currency: string
          fx_rates: Json
          id: string
          name: string
          settings: Json
          strategy: Json
          timezone: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          default_currency?: string
          fx_rates?: Json
          id?: string
          name?: string
          settings?: Json
          strategy?: Json
          timezone?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          default_currency?: string
          fx_rates?: Json
          id?: string
          name?: string
          settings?: Json
          strategy?: Json
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      installment_payments: {
        Row: {
          amount: number
          id: string
          installment_number: number
          paid: boolean | null
          paid_at: string | null
          period_month: number
          period_year: number
          plan_id: string
          transaction_id: string | null
        }
        Insert: {
          amount: number
          id?: string
          installment_number: number
          paid?: boolean | null
          paid_at?: string | null
          period_month: number
          period_year: number
          plan_id: string
          transaction_id?: string | null
        }
        Update: {
          amount?: number
          id?: string
          installment_number?: number
          paid?: boolean | null
          paid_at?: string | null
          period_month?: number
          period_year?: number
          plan_id?: string
          transaction_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "installment_payments_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "installment_plans"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "installment_payments_transaction_id_fkey"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      installment_plans: {
        Row: {
          account_id: string | null
          category: string | null
          created_at: string | null
          created_by: string | null
          currency: string
          household_id: string
          id: string
          name: string
          note: string | null
          start_month: number
          start_year: number
          status: string | null
          total_amount: number
          total_installments: number
          updated_at: string | null
        }
        Insert: {
          account_id?: string | null
          category?: string | null
          created_at?: string | null
          created_by?: string | null
          currency?: string
          household_id: string
          id?: string
          name: string
          note?: string | null
          start_month: number
          start_year: number
          status?: string | null
          total_amount: number
          total_installments: number
          updated_at?: string | null
        }
        Update: {
          account_id?: string | null
          category?: string | null
          created_at?: string | null
          created_by?: string | null
          currency?: string
          household_id?: string
          id?: string
          name?: string
          note?: string | null
          start_month?: number
          start_year?: number
          status?: string | null
          total_amount?: number
          total_installments?: number
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "installment_plans_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "installment_plans_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      recurring_transactions: {
        Row: {
          account: string | null
          active: boolean | null
          amount: number
          category: string
          created_at: string | null
          end_date: string | null
          frequency: string
          household_id: string
          id: string
          next_date: string | null
          note: string | null
          start_date: string
          subcategory: string | null
          type: string
          user_id: string
        }
        Insert: {
          account?: string | null
          active?: boolean | null
          amount: number
          category: string
          created_at?: string | null
          end_date?: string | null
          frequency?: string
          household_id?: string
          id?: string
          next_date?: string | null
          note?: string | null
          start_date: string
          subcategory?: string | null
          type: string
          user_id: string
        }
        Update: {
          account?: string | null
          active?: boolean | null
          amount?: number
          category?: string
          created_at?: string | null
          end_date?: string | null
          frequency?: string
          household_id?: string
          id?: string
          next_date?: string | null
          note?: string | null
          start_date?: string
          subcategory?: string | null
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "recurring_transactions_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      strategy: {
        Row: {
          household_id: string
          investment_percent: number
          savings_percent: number
          updated_at: string
          use_global: boolean
          user_id: string
        }
        Insert: {
          household_id?: string
          investment_percent?: number
          savings_percent?: number
          updated_at?: string
          use_global?: boolean
          user_id: string
        }
        Update: {
          household_id?: string
          investment_percent?: number
          savings_percent?: number
          updated_at?: string
          use_global?: boolean
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "strategy_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: true
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      subscriptions: {
        Row: {
          canceled_at: string | null
          created_at: string
          entitlement_id: string
          environment: string
          event_id: string | null
          expires_at: string | null
          id: string
          latest_receipt_hash: string | null
          metadata: Json
          original_transaction_id: string | null
          period_type: string | null
          product_id: string
          purchased_at: string | null
          renewed_at: string | null
          revenuecat_user_id: string | null
          status: string
          store: string
          unsubscribe_detected_at: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          canceled_at?: string | null
          created_at?: string
          entitlement_id: string
          environment?: string
          event_id?: string | null
          expires_at?: string | null
          id?: string
          latest_receipt_hash?: string | null
          metadata?: Json
          original_transaction_id?: string | null
          period_type?: string | null
          product_id: string
          purchased_at?: string | null
          renewed_at?: string | null
          revenuecat_user_id?: string | null
          status: string
          store: string
          unsubscribe_detected_at?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          canceled_at?: string | null
          created_at?: string
          entitlement_id?: string
          environment?: string
          event_id?: string | null
          expires_at?: string | null
          id?: string
          latest_receipt_hash?: string | null
          metadata?: Json
          original_transaction_id?: string | null
          period_type?: string | null
          product_id?: string
          purchased_at?: string | null
          renewed_at?: string | null
          revenuecat_user_id?: string | null
          status?: string
          store?: string
          unsubscribe_detected_at?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      transaction_templates: {
        Row: {
          amount: number
          category: string
          created_at: string | null
          created_by: string | null
          currency: string
          emoji: string | null
          household_id: string
          id: string
          name: string
          note: string | null
          position: number
          subcategory: string | null
          type: string
        }
        Insert: {
          amount: number
          category: string
          created_at?: string | null
          created_by?: string | null
          currency?: string
          emoji?: string | null
          household_id: string
          id?: string
          name: string
          note?: string | null
          position?: number
          subcategory?: string | null
          type: string
        }
        Update: {
          amount?: number
          category?: string
          created_at?: string | null
          created_by?: string | null
          currency?: string
          emoji?: string | null
          household_id?: string
          id?: string
          name?: string
          note?: string | null
          position?: number
          subcategory?: string | null
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "transaction_templates_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      transactions: {
        Row: {
          account: string | null
          account_id: string | null
          amount: number
          amount_original: number | null
          category: string
          created_at: string
          currency_original: string | null
          date: string
          fx_rate_to_base: number | null
          fx_source: string | null
          fx_status: string | null
          household_id: string
          id: string
          note: string | null
          period_month: number | null
          period_year: number | null
          subcategory: string | null
          transfer_group_id: string | null
          type: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          account?: string | null
          account_id?: string | null
          amount?: number
          amount_original?: number | null
          category: string
          created_at?: string
          currency_original?: string | null
          date: string
          fx_rate_to_base?: number | null
          fx_source?: string | null
          fx_status?: string | null
          household_id?: string
          id?: string
          note?: string | null
          period_month?: number | null
          period_year?: number | null
          subcategory?: string | null
          transfer_group_id?: string | null
          type: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          account?: string | null
          account_id?: string | null
          amount?: number
          amount_original?: number | null
          category?: string
          created_at?: string
          currency_original?: string | null
          date?: string
          fx_rate_to_base?: number | null
          fx_source?: string | null
          fx_status?: string | null
          household_id?: string
          id?: string
          note?: string | null
          period_month?: number | null
          period_year?: number | null
          subcategory?: string | null
          transfer_group_id?: string | null
          type?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "transactions_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transactions_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      user_access_anchors: {
        Row: {
          created_at: string
          ios_original_purchase_date: string | null
          trial_started_at: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          ios_original_purchase_date?: string | null
          trial_started_at?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          ios_original_purchase_date?: string | null
          trial_started_at?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_entitlements: {
        Row: {
          entitlement: string
          expires_at: string | null
          is_active: boolean
          updated_at: string
          user_id: string
        }
        Insert: {
          entitlement: string
          expires_at?: string | null
          is_active?: boolean
          updated_at?: string
          user_id: string
        }
        Update: {
          entitlement?: string
          expires_at?: string | null
          is_active?: boolean
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      wallet_movements: {
        Row: {
          amount: number
          created_at: string | null
          currency: string | null
          date: string
          description: string | null
          external_id: string | null
          household_id: string
          id: string
          metadata: Json | null
          status: string | null
          synced_tx_id: string | null
          type: string
          user_id: string
          wallet_id: string | null
        }
        Insert: {
          amount: number
          created_at?: string | null
          currency?: string | null
          date: string
          description?: string | null
          external_id?: string | null
          household_id?: string
          id?: string
          metadata?: Json | null
          status?: string | null
          synced_tx_id?: string | null
          type: string
          user_id: string
          wallet_id?: string | null
        }
        Update: {
          amount?: number
          created_at?: string | null
          currency?: string | null
          date?: string
          description?: string | null
          external_id?: string | null
          household_id?: string
          id?: string
          metadata?: Json | null
          status?: string | null
          synced_tx_id?: string | null
          type?: string
          user_id?: string
          wallet_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "wallet_movements_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_movements_synced_tx_id_fkey"
            columns: ["synced_tx_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_movements_wallet_id_fkey"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "connected_wallets"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      v_transfer_health: {
        Row: {
          desbalance: number | null
          gastos: number | null
          household_id: string | null
          ingresos: number | null
          piernas: number | null
          transfer_group_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "transactions_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      accept_household_invitation: {
        Args: { invite_token: string }
        Returns: string
      }
      account_balances: {
        Args: { p_household: string }
        Returns: {
          account_id: string
          balance: number
        }[]
      }
      ai_check_and_increment_quota: {
        Args: {
          p_cache_read_tokens?: number
          p_cache_write_tokens?: number
          p_daily_limit?: number
          p_input_tokens?: number
          p_monthly_limit?: number
          p_output_tokens?: number
          p_user_id: string
        }
        Returns: {
          allowed: boolean
          daily_used: number
          monthly_used: number
        }[]
      }
      budget_period_summary: {
        Args: { p_period_id: string }
        Returns: {
          base_currency: string
          fx_missing_count: number
          period_id: string
          ready_to_assign: number
          total_allocated: number
          total_budgeted: number
          total_income: number
        }[]
      }
      create_household: {
        Args: { p_currency?: string; p_name: string; p_timezone?: string }
        Returns: {
          created_at: string
          created_by: string | null
          default_currency: string
          fx_rates: Json
          id: string
          name: string
          settings: Json
          strategy: Json
          timezone: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "households"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_transfer: {
        Args: {
          p_amount: number
          p_date: string
          p_from_account: string
          p_household: string
          p_note?: string
          p_to_account: string
        }
        Returns: string
      }
      delete_transfer: { Args: { p_group: string }; Returns: number }
      envelope_balance: {
        Args: {
          p_category: string
          p_period_id: string
          p_subcategory?: string
        }
        Returns: number
      }
      get_wallet_access_token: { Args: { wid: string }; Returns: string }
      has_active_entitlement: { Args: { ent: string }; Returns: boolean }
      latest_fx_rate: {
        Args: { p_base: string; p_quote: string }
        Returns: number
      }
      month_summary: {
        Args: { p_household: string; p_month: number; p_year: number }
        Returns: {
          gastos: number
          ingresos: number
          movimientos: number
          neto: number
        }[]
      }
      spending_insights: {
        Args: { p_household: string; p_limit?: number }
        Returns: {
          actual: number
          category: string
          delta_pct: number
          direccion: string
          promedio: number
        }[]
      }
      suggest_category: {
        Args: { p_household: string; p_note: string }
        Returns: {
          category: string
          confidence: number
          matched_pattern: string
          subcategory: string
        }[]
      }
      transaction_totals: {
        Args: { p_from: string; p_household: string; p_to: string }
        Returns: {
          gastos: number
          ingresos: number
        }[]
      }
      wallet_encryption_key: { Args: never; Returns: string }
      web_access_state: { Args: never; Returns: Json }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
