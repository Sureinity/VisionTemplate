import type { Route } from "./+types/home";
import { LinkButton } from "../components/Button";
import { SITE } from "../config";

export function meta({}: Route.MetaArgs) {
  return [
    { title: SITE.name },
    { name: "description", content: SITE.description },
  ];
}

const features = [
  {
    title: "Styled out of the box",
    description:
      "Geist type, a cool indigo palette, hairline borders, and dark mode by default — all wired to semantic tokens.",
  },
  {
    title: "Reusable pieces",
    description:
      "Button, navbar, footer, and theme toggle are ready to drop in. Build your demo, not your boilerplate.",
  },
  {
    title: "Clone and go",
    description:
      "Spin up a new repo from this template, rename it in app/config.ts, and you have a clean canvas in seconds.",
  },
];

export default function Home() {
  const items: string[] = undefined as unknown as string[];
  items.map((i) => i);   // throws at SSR render, not at build
  return (
    <>
      {/* Hero */}
      <section className="relative overflow-hidden">
        <div className="bg-grid pointer-events-none absolute inset-0 -z-10" />
        <div className="pointer-events-none absolute inset-0 -z-10 overflow-hidden">
          <div className="aurora aurora-1 left-[8%] top-[-10%] h-[26rem] w-[26rem]" />
          <div className="aurora aurora-2 right-[6%] top-[6%] h-[22rem] w-[22rem]" />
        </div>

        <div className="container mx-auto flex flex-col items-center px-4 pb-20 pt-16 text-center sm:pb-28 sm:pt-24">
          <span className="mb-8 inline-flex items-center gap-2 rounded-full border border-border bg-card/70 px-4 py-1.5 text-sm text-muted-foreground shadow-xs backdrop-blur">
            <span className="h-1.5 w-1.5 rounded-full bg-accent-2" />
            Demo template
          </span>

          <h1 className="text-display text-balance max-w-4xl text-foreground">
            A clean canvas for your <span className="gradient-text-brand">next demo</span>
          </h1>

          <p className="mt-7 max-w-2xl text-lg leading-relaxed text-muted-foreground sm:text-xl">
            {SITE.name} ships with a polished design system, sensible defaults,
            and the building blocks you need — so you can focus on the idea
            you're showing off.
          </p>

          <div className="mt-10 flex flex-col gap-3 sm:flex-row">
            <LinkButton to="/" size="lg">
              Get started
            </LinkButton>
            <LinkButton
              to="https://reactrouter.com/docs"
              size="lg"
              variant="outline"
              reloadDocument
            >
              React Router docs
            </LinkButton>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="container mx-auto px-4 py-20 sm:py-28">
        <div className="mx-auto grid max-w-5xl gap-4 md:grid-cols-3">
          {features.map((feature) => (
            <div
              key={feature.title}
              className="card-lift rounded-xl border border-border bg-card p-7"
            >
              <h3 className="text-lg font-semibold text-foreground">
                {feature.title}
              </h3>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                {feature.description}
              </p>
            </div>
          ))}
        </div>
      </section>
    </>
  );
}
