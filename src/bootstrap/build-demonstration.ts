import { BUILD_EXAMPLES } from '../content/build-examples.ts';
import { builtinContent } from './content.ts';
import { createBuildDemonstration as createIsolatedDemonstration } from '../application/BuildDemonstration.ts';

export const buildExamples = BUILD_EXAMPLES;
export const createBuildDemonstration = (id: string) => {
  const example = BUILD_EXAMPLES.find(item => item.id === id);
  if (!example) throw Error(`Unknown build example ${id}`);
  return createIsolatedDemonstration(builtinContent, example);
};
