export default function Page() {
  return (
    <main style={{ padding: 24, fontFamily: "system-ui" }}>
      <h1>ai-agency-boss</h1>
      <p>Frontend skeleton is ready.</p>
      <p>API base URL: {process.env.NEXT_PUBLIC_API_BASE_URL}</p>
    </main>
  );
}
