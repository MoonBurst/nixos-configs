{ pkgs }:

pkgs.writeTextFile {
  name = "homepage-webroot";
  destination = "/index.html";
  text = ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Moonburst Hub</title>
      <style>
        *, *::before, *::after {
          box-sizing: border-box !important;
        }

        body {
          font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
          background-color: #0F0F0F !important;
          color: #F7F700 !important;
          display: flex !important;
          justify-content: center !important;
          align-items: center !important;
          min-height: 100vh !important;
          margin: 0 !important;
          padding: 20px !important;
        }

        .card {
          text-align: center !important;
          background-color: #12131c !important;
          padding: 3rem 2.5rem !important;
          border-radius: 8px !important;
          box-shadow: 0 0 0 5px #003399 !important;
          border: none !important;
          max-width: 440px !important;
          width: 100% !important;
          display: flex !important;
          flex-direction: column !important;
          gap: 1.5rem !important;
        }

        .header-group {
          display: flex !important;
          flex-direction: column !important;
          gap: 6px !important;
        }

        h1 {
          color: #FABD2F !important;
          font-size: 2.2rem !important;
          font-weight: 800 !important;
          margin: 0 !important;
          letter-spacing: -0.5px !important;
        }

        p {
          color: #FABD2F !important;
          font-size: 0.95rem !important;
          opacity: 0.85 !important;
          margin: 0 !important;
          font-weight: 500 !important;
        }

        .link-group {
          display: flex !important;
          flex-direction: column !important;
          gap: 16px !important;
          margin-top: 8px !important;
        }

        /* Buttons matching MicroBin: dark obsidian with yellow text */
        .btn,
        .btn:link,
        .btn:visited {
          display: flex !important;
          align-items: center !important;
          justify-content: center !important;
          background-color: #0F0F0F !important;
          color: #F7F700 !important;
          box-shadow: 0 0 0 5px #003399 !important;
          border-radius: 8px !important;
          border: none !important;
          padding: 16px 20px !important;
          font-size: 15px !important;
          font-weight: bold !important;
          cursor: pointer !important;
          text-decoration: none !important;
          outline: none !important;
          transition: box-shadow 0.15s ease-in-out, transform 0.15s ease-in-out !important;
        }

        .btn:hover,
        .btn:focus,
        .btn:active {
          background-color: #0F0F0F !important;
          box-shadow: 0 0 0 5px #F7F700, 0 0 25px 6px rgba(247, 247, 0, 0.75) !important;
          color: #F7F700 !important;
          transform: scale(1.02) !important;
        }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="header-group">
          <h1>Moonburst</h1>
          <p>Services Portal</p>
        </div>
        <div class="link-group">
          <a class="btn" href="https://matrix.moonburst.net">💬 Matrix Chat</a>
          <a class="btn" href="https://music.moonburst.net">🎵 Music Streamer (FLAC)</a>
          <a class="btn" href="https://audiobooks.moonburst.net">📚 Audiobooks & Podcasts</a>
          <a class="btn" href="https://share.moonburst.net">🔒 Encrypted Share Drop (24h)</a>
        </div>
      </div>
    </body>
    </html>
  '';
}
