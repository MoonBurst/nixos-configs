{ pkgs }:

pkgs.writeTextDir "index.html" ''
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Moon Burst's Page</title>
    <style>
      body {
        font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
        background-color: #0d0e15;
        color: #f4f4f5;
        display: flex;
        justify-content: center;
        align-items: center;
        height: 100vh;
        margin: 0;
      }
      .card {
        text-align: center;
        background: #161722;
        padding: 3rem;
        border-radius: 12px;
        box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.3);
        border: 1px solid #27272a;
        max-width: 360px;
        width: 100%;
      }
      h1 {
        color: #c084fc;
        font-size: 2.5rem;
        margin-top: 0;
        margin-bottom: 0.5rem;
      }
      p {
        color: #a1a1aa;
        font-size: 1.1rem;
        margin-bottom: 2rem;
      }
      .link-group {
        display: flex;
        flex-direction: column;
        gap: 1rem;
      }
      .btn {
        display: block;
        background-color: #1f202e;
        color: #f4f4f5;
        text-decoration: none;
        font-weight: 600;
        padding: 0.8rem 1.5rem;
        border-radius: 8px;
        border: 1px solid #3f3f46;
        transition: all 0.2s ease-in-out;
      }
      .btn:hover {
        background-color: #c084fc;
        color: #0d0e15;
        border-color: #c084fc;
        transform: translateY(-2px);
      }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>Moonburst</h1>
      <p>Services Portal</p>
      <div class="link-group">
        <a class="btn" href="https://matrix.moonburst.net">Matrix Chat</a>
        <a class="btn" href="https://login.moonburst.net">Login Portal</a>
        <a class="btn" href="https://fluxer.moonburst.net">Fluxer</a>
      </div>
    </div>
  </body>
  </html>
''
