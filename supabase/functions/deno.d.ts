// Ambient type declarations for Deno runtime in Supabase Edge Functions
declare namespace Deno {
  export interface Env {
    get(key: string): string | undefined;
  }
  export const env: Env;
  export function serve(handler: (req: Request) => Promise<Response> | Response): void;
}

declare module "npm:@supabase/supabase-js@2" {
  export const createClient: any;
}
