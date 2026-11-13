// Greeting helpers
import { Injectable } from '@angular/core';

/* block
   comment */
interface User {
  id: number;
  name: string;
  tags?: string[];
}

@Injectable()
export class Greeter<T extends User> {
  private readonly limit = 0x1f + 42.5;
  constructor(private users: T[]) {}

  greet(u: T): string {
    const safe = u.name.replace('<', '&lt;');
    return `hi ${safe} (#${u.id})`;
  }
}

export const first = async (g: Greeter<User>): Promise<string | undefined> => g.greet({ id: 1, name: 'Ada' });
