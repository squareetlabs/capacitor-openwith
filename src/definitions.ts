export interface OpenWithPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
