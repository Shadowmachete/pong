#include <stdio.h>
#include <time.h>
#include <SDL2/SDL.h>
#include <SDL2/SDL_timer.h>
#include <SDL2/SDL_ttf.h>

const int paddleDims[2] = {32, 384};
const int circleRadius = 20;

int speed = 600;
int leftPts = 0, rightPts = 0;

typedef struct {
  int x, y;
} Point;

typedef struct {
  SDL_Point *circlePoints;
  int numPoints;
  Point circleCenter;
  Point velocity;
} Circle;

#define min(a,b) \
  (((a) < (b)) ? (a) : (b))

#define max(a,b) \
  (((a) > (b)) ? (a) : (b))

#define MY_FONT "/usr/share/fonts/TTF/Hack-Regular.ttf"

int calculateNumPoints() {
  int x = 0, y = circleRadius;
  int d = 3 - 2 * circleRadius;
  int counter = 1;
  while (y >= x) {
    if (d > 0) {
      y--;
      d += 4 * (x - y) + 10;
    } else {
      d += 4 * x + 6;
    }

    x++;
    counter++;
  }

  return counter * 8;
}

void addPoints(SDL_Point *points, Point circleCenter, int x, int y, int counter) {
  points[counter * 8 + 0].x = circleCenter.x + x; points[counter * 8 + 0].y = circleCenter.y + y;
  points[counter * 8 + 1].x = circleCenter.x - x; points[counter * 8 + 1].y = circleCenter.y + y;
  points[counter * 8 + 2].x = circleCenter.x + x; points[counter * 8 + 2].y = circleCenter.y - y;
  points[counter * 8 + 3].x = circleCenter.x - x; points[counter * 8 + 3].y = circleCenter.y - y;
  points[counter * 8 + 4].x = circleCenter.x + y; points[counter * 8 + 4].y = circleCenter.y + x;
  points[counter * 8 + 5].x = circleCenter.x - y; points[counter * 8 + 5].y = circleCenter.y + x;
  points[counter * 8 + 6].x = circleCenter.x + y; points[counter * 8 + 6].y = circleCenter.y - x;
  points[counter * 8 + 7].x = circleCenter.x - y; points[counter * 8 + 7].y = circleCenter.y - x;
}

void updateCirclePoints(Circle circle) {
  SDL_Point *points = circle.circlePoints;
  Point circleCenter = circle.circleCenter;
  int x = 0, y = circleRadius;
  int d = 3 - 2 * circleRadius;
  int counter = 0;
  addPoints(points, circleCenter, x, y, counter);
  counter++;

  while (y >= x) {
    if (d > 0) {
      y--;
      d += 4 * (x - y) + 10;
    } else {
      d += 4 * x + 6;
    }

    x++;

    addPoints(points, circleCenter, x, y, counter);
    counter++;
  }
}

void calcNewVelocity(SDL_Rect paddle, Point circleCenter, Point *oldVelocity) {
  float paddleCenterY = paddle.y + paddle.h / 2;
  float dy = circleCenter.y - paddleCenterY;
  float normalized = dy / (paddle.h / 2);
  float maxAngle = 75.0 * M_PI / 180.0f;
  float bounceAngle = ((float)rand()/(float)(RAND_MAX/2.0f)) * normalized * maxAngle;
  float speed = sqrtf(oldVelocity->x * oldVelocity->x + oldVelocity->y * oldVelocity->y);
  *oldVelocity = (Point){ (int)-copysignf(speed * cosf(bounceAngle), (int)oldVelocity->x), speed * sinf(bounceAngle) };
}

int main(void)
{
  if (SDL_Init(SDL_INIT_EVERYTHING) != 0) {
    printf("error initializing SDL: %s\n", SDL_GetError());
    return 1;
  }

  if (TTF_Init() < 0) {
    printf("error initialising TTF: %s\n", TTF_GetError());
    SDL_Quit();
    return 1;
  }

  srand(time(NULL));

  SDL_DisplayMode dm;

  if (SDL_GetDesktopDisplayMode(0, &dm) != 0) {
    SDL_Log("SDL_GetDesktopDisplayMode failed: %s", SDL_GetError());
    SDL_Quit();
    return 1;
  }

  int w, h;
  w = dm.w;
  h = dm.h;

  SDL_Log("Height and width of screen: (%d, %d)", h, w);

  SDL_Window* win = SDL_CreateWindow("GAME",
                                      SDL_WINDOWPOS_CENTERED,
                                      SDL_WINDOWPOS_CENTERED,
                                      w, h, SDL_WINDOW_FULLSCREEN_DESKTOP);

  if (!win) {
    SDL_Log("Failed to create window: %s", SDL_GetError());
    SDL_Quit();
    return 1;
  }

  Uint32 render_flags = SDL_RENDERER_ACCELERATED;

  SDL_Renderer* rend = SDL_CreateRenderer(win, -1, render_flags);

  if (!rend) {
    SDL_Log("Failed to create renderer: %s", SDL_GetError());
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 1;
  }

  const int centerW = w / 2;
  const int centerH = h / 2;

  SDL_Point middleLine[100];

  for (int i = 0; i < 100; i++) {
    middleLine[i].x = centerW;
    middleLine[i].y = (h * i) / 100;
  }

  TTF_Font *font = TTF_OpenFont(MY_FONT, 24);

  if (!font) {
    printf("Failed to load font: %s\n", TTF_GetError());
    SDL_Quit();
    return 1;
  }

  SDL_Color White = {255, 255, 255, 255};

  char leftScoreBuffer[100], rightScoreBuffer[100];

  snprintf(leftScoreBuffer, 100, "Score: %d", leftPts);

  SDL_Surface *leftScoreSurface = TTF_RenderText_Solid(font, leftScoreBuffer, White);

  if (!leftScoreSurface) {
    printf("Failed to create text surface: %s\n", TTF_GetError());
    SDL_Quit();
    return 1;
  }

  SDL_Texture *leftScoreTexture = SDL_CreateTextureFromSurface(rend, leftScoreSurface);

  if (!leftScoreTexture) {
    printf("Failed to create text texture: %s\n", SDL_GetError());
    SDL_Quit();
    return 1;
  }

  snprintf(rightScoreBuffer, 100, "Score: %d", rightPts);

  SDL_Surface *rightScoreSurface = TTF_RenderText_Solid(font, rightScoreBuffer, White);

  if (!rightScoreSurface) {
    printf("Failed to create text surface: %s\n", TTF_GetError());
    SDL_Quit();
    return 1;
  }

  SDL_Texture *rightScoreTexture = SDL_CreateTextureFromSurface(rend, rightScoreSurface);

  if (!rightScoreTexture) {
    printf("Failed to create text texture: %s\n", SDL_GetError());
    SDL_Quit();
    return 1;
  }

  SDL_Rect leftScoreMessageRect = { centerW - 200, 50, 100, 100 };
  SDL_Rect rightScoreMessageRect = { centerW + 100, 50, 100, 100 } ;

  const int leftPaddleX = (int)(0.1 * centerW);
  const int rightPaddleX = w - (int)(0.1 * centerW);

  SDL_Rect leftPaddle;
  SDL_Rect rightPaddle;

  leftPaddle.x = leftPaddleX;
  leftPaddle.y = centerH - paddleDims[1] / 2;
  leftPaddle.w = paddleDims[0];
  leftPaddle.h = paddleDims[1];

  rightPaddle.x = rightPaddleX;
  rightPaddle.y = centerH - paddleDims[1] / 2;
  rightPaddle.w = paddleDims[0];
  rightPaddle.h = paddleDims[1];

  Circle ball;

  ball.numPoints = calculateNumPoints();
  ball.circlePoints = malloc(ball.numPoints * sizeof(SDL_Point));
  ball.circleCenter = (Point){ centerW, centerH };
  ball.velocity = (Point){ 10, 0 };

  int close = 0;

  float closestX, closestY, dx, dy;
  SDL_Rect paddle;

  while (!close) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
      switch (event.type) {

      case SDL_QUIT:
        // handling of close button
        close = 1;
        break;

      case SDL_KEYDOWN:
        // keyboard API for key pressed
        switch (event.key.keysym.scancode) {
        case SDL_SCANCODE_W:
          if (leftPaddle.y > speed / 30) {
            leftPaddle.y -= speed / 30;
          }
          break;
        case SDL_SCANCODE_S:
          if (leftPaddle.y + leftPaddle.h < h - speed / 30) {
            leftPaddle.y += speed / 30;
          }
          break;
        case SDL_SCANCODE_UP:
          if (rightPaddle.y > speed / 30) {
            rightPaddle.y -= speed / 30;
          }
          break;
        case SDL_SCANCODE_DOWN:
          if (rightPaddle.y + rightPaddle.h < h - speed / 30) {
            rightPaddle.y += speed / 30;
          }
          break;
        case SDL_SCANCODE_ESCAPE:
        case SDL_SCANCODE_Q:
          close = 1;
          break;
        default:
          break;
        }
      }
    }

    SDL_SetRenderDrawColor(rend, 0, 0, 0, 255);
    SDL_RenderClear(rend);

    SDL_SetRenderDrawColor(rend, 255, 255, 255, 255);

    // middle line
    SDL_RenderDrawPoints(rend, middleLine, 100);

    // score
    SDL_RenderCopy(rend, leftScoreTexture, NULL, &leftScoreMessageRect);
    SDL_RenderCopy(rend, rightScoreTexture, NULL, &rightScoreMessageRect);

    // paddles
    SDL_RenderDrawRect(rend, &leftPaddle);
    SDL_RenderDrawRect(rend, &rightPaddle);

    SDL_RenderFillRect(rend, &leftPaddle);
    SDL_RenderFillRect(rend, &rightPaddle);

    // ball
    updateCirclePoints(ball);
    SDL_RenderDrawPoints(rend, ball.circlePoints, ball.numPoints);

    for (int y = ball.circleCenter.y - circleRadius; y <= ball.circleCenter.y + circleRadius; y++) {
      int dx = (int)sqrt(circleRadius * circleRadius - (y - ball.circleCenter.y) * (y - ball.circleCenter.y));
      int x1 = ball.circleCenter.x - dx;
      int x2 = ball.circleCenter.x + dx;

      SDL_RenderDrawLine(rend, x1, y, x2, y);
    }

    SDL_RenderPresent(rend);

    if (ball.circleCenter.y - circleRadius + ball.velocity.y < 0 || ball.circleCenter.y + circleRadius + ball.velocity.y > h) {
      ball.velocity.y = -ball.velocity.y;

      if (ball.velocity.x == 0) {
        ball.velocity.x = (ball.circleCenter.x < centerW) ? 1 : -1;
      }
    }

    if (ball.circleCenter.x < centerW) {
      paddle = leftPaddle;
    } else {
      paddle = rightPaddle;
    }

    closestX = max(paddle.x, min(ball.circleCenter.x, paddle.x + paddle.w));
    closestY = max(paddle.y, min(ball.circleCenter.y, paddle.y + paddle.h));

    dx = ball.circleCenter.x - closestX;
    dy = ball.circleCenter.y - closestY;

    if ((dx * dx + dy * dy) < (circleRadius * circleRadius)) {
      // ball.velocity = calcNewVelocity(paddle, ball.circleCenter, ball.velocity);
      if ((ball.circleCenter.x < centerW && ball.velocity.x < 0) ||
          (ball.circleCenter.x > centerW && ball.velocity.x > 0)) {

        calcNewVelocity(paddle, ball.circleCenter, &ball.velocity);

        // Move ball just outside the paddle to avoid sticking
        if (ball.circleCenter.x < centerW) {
          ball.circleCenter.x = paddle.x + paddle.w + circleRadius;
        } else {
          ball.circleCenter.x = paddle.x - circleRadius;
        }
      }
    }

    ball.circleCenter.x += ball.velocity.x;
    ball.circleCenter.y += ball.velocity.y;

    if (ball.circleCenter.x < 0) {
      // off screen on the left
      rightPts++;
      ball.circleCenter = (Point){ centerW, centerH };
      ball.velocity = (Point){ 10, 0 };
      SDL_Log("Right player got a point.");
      snprintf(rightScoreBuffer, 100, "Score: %d", rightPts);

      rightScoreSurface = TTF_RenderText_Solid(font, rightScoreBuffer, White);

      if (!rightScoreSurface) {
        printf("Failed to create text surface: %s\n", TTF_GetError());
        SDL_Quit();
        return 1;
      }

      rightScoreTexture = SDL_CreateTextureFromSurface(rend, rightScoreSurface);

      if (!rightScoreTexture) {
        printf("Failed to create text texture: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
      }
    } else if (ball.circleCenter.x > w) {
      // off screen on the right
      leftPts++;
      ball.circleCenter = (Point){ centerW, centerH };
      ball.velocity = (Point){ -10, 0 };
      SDL_Log("Left player got a point.");
      snprintf(leftScoreBuffer, 100, "Score: %d", leftPts);

      leftScoreSurface = TTF_RenderText_Solid(font, leftScoreBuffer, White);

      if (!leftScoreSurface) {
        printf("Failed to create text surface: %s\n", TTF_GetError());
        SDL_Quit();
        return 1;
      }

      leftScoreTexture = SDL_CreateTextureFromSurface(rend, leftScoreSurface);

      if (!leftScoreTexture) {
        printf("Failed to create text texture: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
      }
    }

    SDL_Delay(1000 / 60);
  }

  // Free suface and texture
  SDL_FreeSurface(leftScoreSurface);
  SDL_FreeSurface(rightScoreSurface);
  SDL_DestroyTexture(leftScoreTexture);
  SDL_DestroyTexture(rightScoreTexture);

  // destroy renderer
  SDL_DestroyRenderer(rend);

  // destroy window
  SDL_DestroyWindow(win);

  // close SDL
  SDL_Quit();

  // free
  free(ball.circlePoints);

  return 0;
}
