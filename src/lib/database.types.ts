export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      achievement_definitions: {
        Row: {
          code: string
          created_at: string
          description: string
          icon: string | null
          id: string
          rule_params: Json
          rule_type: string
          title: string
        }
        Insert: {
          code: string
          created_at?: string
          description: string
          icon?: string | null
          id?: string
          rule_params?: Json
          rule_type: string
          title: string
        }
        Update: Partial<Database['public']['Tables']['achievement_definitions']['Insert']>
        Relationships: []
      }
      clubs: {
        Row: {
          county_id: string
          created_at: string
          crest_url: string | null
          founded_year: number | null
          history: string | null
          home_ground_id: string | null
          id: string
          name: string
          sport_code: Database['public']['Enums']['sport_code']
        }
        Insert: {
          county_id: string
          created_at?: string
          crest_url?: string | null
          founded_year?: number | null
          history?: string | null
          home_ground_id?: string | null
          id?: string
          name: string
          sport_code: Database['public']['Enums']['sport_code']
        }
        Update: Partial<Database['public']['Tables']['clubs']['Insert']>
        Relationships: []
      }
      counties: {
        Row: {
          created_at: string
          crest_url: string | null
          id: string
          name: string
          primary_colour: string | null
          province: Database['public']['Enums']['province']
          secondary_colour: string | null
        }
        Insert: {
          created_at?: string
          crest_url?: string | null
          id?: string
          name: string
          primary_colour?: string | null
          province: Database['public']['Enums']['province']
          secondary_colour?: string | null
        }
        Update: Partial<Database['public']['Tables']['counties']['Insert']>
        Relationships: []
      }
      county_teams: {
        Row: {
          county_id: string
          created_at: string
          current_manager: string | null
          founded_year: number | null
          history: string | null
          id: string
          sport_code: Database['public']['Enums']['sport_code']
        }
        Insert: {
          county_id: string
          created_at?: string
          current_manager?: string | null
          founded_year?: number | null
          history?: string | null
          id?: string
          sport_code: Database['public']['Enums']['sport_code']
        }
        Update: Partial<Database['public']['Tables']['county_teams']['Insert']>
        Relationships: []
      }
      grounds: {
        Row: {
          capacity: number | null
          county_id: string
          created_at: string
          id: string
          latitude: number
          longitude: number
          name: string
          photo_url: string | null
        }
        Insert: {
          capacity?: number | null
          county_id: string
          created_at?: string
          id?: string
          latitude: number
          longitude: number
          name: string
          photo_url?: string | null
        }
        Update: Partial<Database['public']['Tables']['grounds']['Insert']>
        Relationships: []
      }
      honours: {
        Row: {
          club_id: string | null
          competition_name: string
          county_team_id: string | null
          honour_type: Database['public']['Enums']['honour_type']
          id: string
          team_type: Database['public']['Enums']['team_type']
          year: number
        }
        Insert: {
          club_id?: string | null
          competition_name: string
          county_team_id?: string | null
          honour_type: Database['public']['Enums']['honour_type']
          id?: string
          team_type: Database['public']['Enums']['team_type']
          year: number
        }
        Update: Partial<Database['public']['Tables']['honours']['Insert']>
        Relationships: []
      }
      matches: {
        Row: {
          away_club_id: string | null
          away_county_team_id: string | null
          away_score: string | null
          competition: string | null
          created_at: string
          ground_id: string | null
          home_club_id: string | null
          home_county_team_id: string | null
          home_score: string | null
          id: string
          match_type: Database['public']['Enums']['match_type']
          played_at: string
        }
        Insert: {
          away_club_id?: string | null
          away_county_team_id?: string | null
          away_score?: string | null
          competition?: string | null
          created_at?: string
          ground_id?: string | null
          home_club_id?: string | null
          home_county_team_id?: string | null
          home_score?: string | null
          id?: string
          match_type: Database['public']['Enums']['match_type']
          played_at: string
        }
        Update: Partial<Database['public']['Tables']['matches']['Insert']>
        Relationships: []
      }
      team_grounds: {
        Row: {
          club_id: string | null
          county_team_id: string | null
          ground_id: string
          id: string
          is_home: boolean
          team_type: Database['public']['Enums']['team_type']
        }
        Insert: {
          club_id?: string | null
          county_team_id?: string | null
          ground_id: string
          id?: string
          is_home?: boolean
          team_type: Database['public']['Enums']['team_type']
        }
        Update: Partial<Database['public']['Tables']['team_grounds']['Insert']>
        Relationships: []
      }
      user_achievements: {
        Row: {
          achievement_id: string
          id: string
          unlocked_at: string
          user_id: string
        }
        Insert: {
          achievement_id: string
          id?: string
          unlocked_at?: string
          user_id: string
        }
        Update: Partial<Database['public']['Tables']['user_achievements']['Insert']>
        Relationships: []
      }
      user_match_attendance: {
        Row: {
          created_at: string
          id: string
          match_id: string
          notes: string | null
          photo_urls: string[]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          match_id: string
          notes?: string | null
          photo_urls?: string[]
          user_id: string
        }
        Update: Partial<Database['public']['Tables']['user_match_attendance']['Insert']>
        Relationships: []
      }
      user_profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          display_name: string | null
          id: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          id: string
        }
        Update: Partial<Database['public']['Tables']['user_profiles']['Insert']>
        Relationships: []
      }
      user_visits: {
        Row: {
          created_at: string
          ground_id: string
          id: string
          notes: string | null
          photo_urls: string[]
          user_id: string
          visited_at: string
        }
        Insert: {
          created_at?: string
          ground_id: string
          id?: string
          notes?: string | null
          photo_urls?: string[]
          user_id: string
          visited_at?: string
        }
        Update: Partial<Database['public']['Tables']['user_visits']['Insert']>
        Relationships: []
      }
    }
    Views: { [_ in never]: never }
    Functions: { [_ in never]: never }
    Enums: {
      honour_type: 'all_ireland' | 'provincial' | 'league' | 'county_championship' | 'club_all_ireland'
      match_type: 'county' | 'club'
      province: 'Connacht' | 'Leinster' | 'Munster' | 'Ulster'
      sport_code: 'gaelic_football' | 'hurling' | 'camogie' | 'ladies_football'
      team_type: 'county' | 'club'
    }
    CompositeTypes: { [_ in never]: never }
  }
}

export type Tables<T extends keyof Database['public']['Tables']> = Database['public']['Tables'][T]['Row']
export type Enums<T extends keyof Database['public']['Enums']> = Database['public']['Enums'][T]
